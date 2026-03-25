# Clean Terminal Paste

A tiny shell script that fixes broken formatting when you copy from Terminal (especially Claude Code) and paste into Google Docs, Notion, Slack, or any other app.

## The problem

When you copy text from Terminal, you get:
- **Hard line breaks** at your terminal's column width (80, 120, etc.)
- **ANSI escape codes** (color, bold) that show up as garbage characters
- **Broken paragraphs** — every wrapped line becomes a new line in your document

**Before:**
```
Here is a paragraph that has been hard-wrapped by the terminal at
column 80 so it looks like two lines but it is really one continuous
sentence that should flow together.
```

**After:**
```
Here is a paragraph that has been hard-wrapped by the terminal at column 80 so it looks like two lines but it is really one continuous sentence that should flow together.
```

## What it preserves

The script is smart about what to reflow and what to leave alone:
- Headings (`#`, `##`, etc.)
- Bullet and numbered lists
- Code blocks (fenced with backticks)
- Tables
- Blockquotes
- Blank lines between paragraphs

## Install

```bash
# Download the script
curl -o ~/.local/bin/c https://raw.githubusercontent.com/altisvc/clean-terminal-paste/main/clean-terminal-paste.sh
chmod +x ~/.local/bin/c
```

Make sure `~/.local/bin` is on your PATH. Add this to your `~/.zshrc` if needed:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

Copy text from Terminal, then:

```
c
```

That's it. Your clipboard is now clean — paste anywhere with Cmd+V.

### Inside Claude Code

```
! c
```

### Pipe mode
```bash
pbpaste | c | pbcopy
```

## How it works

1. Strips ANSI escape codes (colors, bold, cursor sequences)
2. Removes carriage returns
3. Joins lines that were soft-wrapped by the terminal — but preserves intentional structure (headings, lists, code blocks, tables, blockquotes, blank lines)
4. Trims trailing whitespace
5. Forces plain text on clipboard (no rich text formatting leaks)

Pure `perl`. No dependencies beyond a standard macOS/Linux shell.

## License

MIT
