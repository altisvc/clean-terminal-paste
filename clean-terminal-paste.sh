#!/usr/bin/env bash
# clean-terminal-paste.sh
# Cleans Terminal/Claude Code clipboard output for pasting into docs, Slack, etc.
# Usage: c                    (cleans clipboard in place)
#        echo "text" | c      (pipe mode, stdin → stdout)

set -euo pipefail

clean() {
perl -CSDA -0777 -e '
    $_ = <STDIN>;

    # Strip ANSI escape codes and carriage returns
    s/\e\[[0-9;]*[a-zA-Z]//g;
    s/\e\][^\a]*\a//g;
    s/\r//g;

    # Strip Claude Code / chat UI message-margin markers (vertical bar chars)
    # ▎ U+258E, ▏ U+258F, ▌ U+258C, ▍ U+258D, │ U+2502, ┃ U+2503, ▕ U+2595
    # Replace marker + surrounding whitespace with a single space so word boundaries survive.
    s/\s*[\x{258E}\x{258F}\x{258C}\x{258D}\x{2502}\x{2503}\x{2595}]\s*/ /g;

    # Normalize em-dashes and en-dashes to plain hyphens
    # Em-dash (—, U+2014) with optional surrounding whitespace → " - "
    s/\s*\x{2014}\s*/ - /g;
    # En-dash (–, U+2013) with optional surrounding whitespace → "-" (no spaces, suits numeric ranges)
    s/\s*\x{2013}\s*/-/g;
    # Horizontal bar (―, U+2015) → " - "
    s/\s*\x{2015}\s*/ - /g;

    # Trim trailing whitespace per line
    s/[ \t]+$//mg;

    # Split into lines, process
    my @lines = split /\n/, $_;
    my @out;
    my $buf = "";
    my $in_code = 0;

    for my $line (@lines) {
        # Code block fences
        if ($line =~ /^```/) {
            push @out, $buf if $buf ne "";
            $buf = "";
            push @out, $line;
            $in_code = !$in_code;
            next;
        }
        # Inside code block: verbatim
        if ($in_code) { push @out, $line; next; }

        # Blank line: flush + preserve
        if ($line =~ /^\s*$/) {
            push @out, $buf if $buf ne "";
            $buf = "";
            push @out, "";
            next;
        }
        # Structural lines: headings, lists, tables, blockquotes, indented code
        if ($line =~ /^\s*(?:#{1,6} |[-*+] |\d+\. |\| |>|    |\t)/) {
            push @out, $buf if $buf ne "";
            $buf = $line;
            next;
        }
        # Continuation: join to buffer
        if ($buf ne "") {
            $buf =~ s/\s+$//;
            $line =~ s/^\s+//;
            # If buffer ends with hyphen inside a URL or long token, join without space
            if ($buf =~ /\S-$/ && $line =~ /^\S/) {
                $buf .= $line;
            } else {
                $buf .= " " . $line;
            }
        } else {
            $line =~ s/^\s+//;
            $buf = $line;
        }
    }
    push @out, $buf if $buf ne "";

    # Strip common leading indentation
    my $min_indent = 9999;
    for my $l (@out) {
        next if $l =~ /^\s*$/;
        $l =~ /^( *)/;
        my $n = length($1);
        $min_indent = $n if $n < $min_indent;
    }
    if ($min_indent > 0 && $min_indent < 9999) {
        for my $l (@out) {
            $l =~ s/^ {$min_indent}//;
        }
    }

    print join("\n", @out) . "\n";
'
}

# Pipe mode: echo "text" | c --pipe
if [ "${1:-}" = "--pipe" ]; then
    clean
    exit 0
fi

# Default: clipboard mode
if [[ "$OSTYPE" == darwin* ]]; then
    pbpaste -Prefer txt | clean | pbcopy -Prefer txt
elif command -v xclip &>/dev/null; then
    xclip -selection clipboard -o | clean | xclip -selection clipboard
elif command -v xsel &>/dev/null; then
    xsel --clipboard --output | clean | xsel --clipboard --input
else
    echo "No clipboard tool found. Install xclip or xsel." >&2
    exit 1
fi
echo "Clipboard cleaned."
