#!/usr/bin/env bash
# clean-terminal-paste.sh
# Cleans Terminal/Claude Code clipboard output for pasting into docs, Slack, etc.
# Usage: c                    (cleans clipboard in place)
#        echo "text" | c      (pipe mode, stdin → stdout)

set -euo pipefail

clean() {
perl -0777 -e '
    $_ = <STDIN>;

    # Strip ANSI escape codes and carriage returns
    s/\e\[[0-9;]*[a-zA-Z]//g;
    s/\e\][^\a]*\a//g;
    s/\r//g;

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
            $buf .= " " . $line;
        } else {
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
pbpaste -Prefer txt | clean | pbcopy -Prefer txt
echo "Clipboard cleaned."
