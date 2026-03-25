#!/usr/bin/env bash
# clean-terminal-paste.sh
# Cleans Terminal/Claude Code clipboard output for pasting into docs, Slack, etc.
# Usage: pbpaste | ./clean-terminal-paste.sh | pbcopy
#   or:  ./clean-terminal-paste.sh  (reads and writes clipboard directly)

set -euo pipefail

# If no stdin, read from clipboard and write back to clipboard
if [ -t 0 ]; then
    pbpaste -Prefer txt | "$0" | pbcopy -Prefer txt
    echo "Clipboard cleaned."
    exit 0
fi

# Single perl pass: strip ANSI, unwrap soft breaks, preserve structure
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
    print join("\n", @out) . "\n";
'
