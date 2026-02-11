# Vim Speed Tips for YAML Editing

You WILL edit YAML in vim on the exam. Get comfortable.

## ~/.vimrc Setup (Do at exam start)

```bash
cat << 'EOF' >> ~/.vimrc
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set number
set cursorline
EOF
```

This ensures: 2-space tabs (YAML standard), spaces not tabs, auto-indent, line numbers.

## Essential Commands

| Key | Action |
|-----|--------|
| `i` | Insert mode (start typing) |
| `Esc` | Back to normal mode |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |
| `u` | Undo |
| `Ctrl+r` | Redo |

## Navigation

| Key | Action |
|-----|--------|
| `gg` | Go to first line |
| `G` | Go to last line |
| `42G` or `:42` | Go to line 42 |
| `0` | Start of line |
| `$` | End of line |
| `w` | Next word |
| `b` | Previous word |
| `{` / `}` | Previous/next paragraph |

## Editing

| Key | Action |
|-----|--------|
| `dd` | Delete line |
| `5dd` | Delete 5 lines |
| `yy` | Copy (yank) line |
| `5yy` | Copy 5 lines |
| `p` | Paste below |
| `P` | Paste above |
| `o` | New line below + insert mode |
| `O` | New line above + insert mode |
| `A` | Append at end of line |
| `cw` | Change word (delete + insert) |
| `cc` | Change entire line |
| `ciw` | Change inner word |

## Indentation (Critical for YAML)

| Key | Action |
|-----|--------|
| `>>` | Indent line right |
| `<<` | Indent line left |
| `5>>` | Indent 5 lines right |
| `V` then select, then `>` | Indent block right |
| `V` then select, then `<` | Indent block left |
| `.` | Repeat last command |

### Indent a block

1. `V` (visual line mode)
2. Move down with `j` to select lines
3. `>` to indent (or `<` to outdent)
4. `.` to repeat

## Search & Replace

| Command | Action |
|---------|--------|
| `/text` | Search forward |
| `?text` | Search backward |
| `n` / `N` | Next / previous match |
| `:%s/old/new/g` | Replace all in file |
| `:s/old/new/g` | Replace all in current line |

## Paste Mode

When pasting YAML from clipboard, indentation gets mangled. Fix:

```
:set paste
```

Then `i` to insert and paste. After pasting:

```
:set nopaste
```

## YAML-Specific Workflows

### Copy a container block and modify it

1. Go to the start of the container block
2. `V` to enter visual line mode
3. Select the entire block with `j`
4. `y` to yank (copy)
5. Move to where you want the new container
6. `p` to paste
7. Modify the pasted block

### Delete from cursor to end of file

```
dG
```

### Delete from cursor to end of line

```
D
```

### Quick duplicate line and edit

```
yyp      # duplicate line
cw       # change first word
```

## Practice Drill

Open any YAML file and practice:

1. Jump to line 10 (`10G`)
2. Delete 3 lines (`3dd`)
3. Undo (`u`)
4. Copy 5 lines (`5yy`)
5. Go to end of file (`G`)
6. Paste (`p`)
7. Select 5 lines and indent (`V4j>`)
8. Search for "image" (`/image`)
9. Save and quit (`:wq`)

Do this 5 times and it becomes automatic.
