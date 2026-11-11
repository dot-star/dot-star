# dot-star

## Install

    mkdir -p ~/Projects
    cd ~/Projects
    git clone https://github.com/dot-star/dot-star.git
    cd dot-star
    ./install.sh

## Everyday aliases

### Git

| Example | Resolves to |
|---------|-------------|
| `cm "Some commit message"` | `git commit -m "Some commit message"` |
| `add file.txt` | `git add file.txt` |
| `co branch` | `git checkout branch` |
| `push` | `git push` |
| `nv "wip"` | `git commit --no-verify -m "wip"` |

### Search

| Example | Resolves to |
|---------|-------------|
| `s` (bare) | `git status` |
| `s "keyword"` | case-insensitive grep for `keyword` |
| `ss "Keyword"` | case-sensitive grep |
| `se "keyword"` | grep, then open matching files in vim |
| `f filter` | find files whose name contains `filter` |

### Diff

| Example | Resolves to |
|---------|-------------|
| `d` (in a git repo) | `git diff` |
| `d before.txt after.txt` | file diff |
| `d ps` (outside a git repo) | `docker ps` |

### Files / editing

| Example | Resolves to |
|---------|-------------|
| `v file.txt` | open `file.txt` in vim |
| `rp ./symlink` | resolve to absolute real path |
| `rm *` | refuses with a warning |

## Worktrees

Work on several branches at once, each checked out in its own directory. Everything here changes local branches only; nothing gets pushed.

| Example | Does |
|---------|------|
| `s` | `git status`, then the repo's worktrees, newest first, with what each one holds |
| `wt` | pick a worktree with fzf and `cd` into it, keeping your subdirectory when it exists there |
| `wt 3` | jump to row 3 of the worktree list `s` printed |
| `wt pattern` | jump to the worktree matching `pattern` |
| `wta` | list every worktree (`s` shows the newest 10) |
| `promote` | fast-forward the default branch to this worktree's commits and keep the worktree |
| `wtd` | land this worktree's commits on the default branch, then delete the worktree and its branch |
| `wtp` | delete every worktree that's merged and clean; report the rest |
| `rr` | go to the main checkout (`r` stops at the worktree's root) |

`wtd` refuses while the worktree has uncommitted changes. When the default branch has moved on, it rebases the worktree's branch onto it first.

## AI helpers

These call the `claude` CLI.

### Pick an AI-written commit message

    $ cmc
    $ cmc "fixes the login redirect"

Drafts five one-line messages for the staged diff and opens them in fzf; the one you pick becomes the commit. An optional note steers the drafts. The model runs with no tools and gets the diff as data, so text inside the diff can't make it do anything. `aic`, `cgc`, `clc`, `clcm` and `cma` do the same.

### Stash with a summary

    $ cstash

Stashes everything (untracked files included) and hands the prompt back right away. In the background, an AI-written summary replaces the stash's default `WIP on <branch>` message.

### Ask a one-off question

    $ ask "find my session about the install script"

Prints Claude's answer. It can read past Claude Code session transcripts and this repo.

### Start or resume a Claude session

    $ cl
    $ clr

`cl` starts a session and `clr` opens the session picker. Inside a worktree, both pick up that worktree's last session instead. Quitting Claude cleanly also closes the terminal window. `cl` refuses to start in a shell left over from inside another session, where Claude would quietly skip saving the transcript.

## Claude Code

### Config

`./install.sh` links `CLAUDE.md`, `settings.json`, hooks, skills and slash commands from `ai/files/Users/user/.claude/` into `~/.claude/`. A link you've already pointed somewhere else is left alone with a warning.

### Context

Three ways to give Claude standing instructions, by how often they're needed:

- **Every session:** `~/.claude/CLAUDE.md`, plus any `CLAUDE_<name>.md` beside it, which a session-start hook loads. Keep these small, since hook output is capped at 10,000 bytes.
- **One repo:** write the doc in `ai/contexts/<name>.md` and import it from that repo's gitignored `CLAUDE.local.md` with `@~/.dot-star/ai/contexts/<name>.md`. No size cap.
- **On mention:** add `<!-- claude-mention: <keyword> -->` to a doc in `ai/contexts/`. The first prompt that mentions the keyword gets a pointer to the doc.

## Examples

### Prevent accidental wildcard deletion

    $ rm *
    cowardly refusing to run `rm' with a dangerous wildcard

### Watch a directory for changes using `wd` and run a test suite

    $ while :; do wd; phpunit MyTest.php; done

### Debug a jq filter

    $ jq api_response.json
    (opens an interactive fzf window for debugging a jq filter)

![](screenshots/jq.png)

### View git stashes

    $ list
    (opens an interactive fzf stash preview window for viewing git stashes in the current repository)

### Apply a git stash

    $ pop
    (opens an interactive fzf stash preview window for selecting a git stash to apply)

### Diff strings

    $ diff_strings_like_files "foo" "foobar"
    
```diff
-foo
+foobar
```

### Rename file using one parameter

    $ mv download.jpg
    the-lorax.jpg
    -download.jpg
    +the-lorax.jpg

### List folders and files in current directory

    $ l

### List folders and files in a tree-like format (using the `tree' command)

    $ t

### Run a smarter git diff

    $ d

### Run a smarter file diff

    $ d before.txt after.txt

### Set clipboard

    $ pwd | clipboard
    $ pwd | clip
    $ cat file.txt | c

### Run `git add --patch'

    $ addp

### Change file permissions

    $ 644 myfile.txt

### Change folder permissions

    $ 400 ~/.ssh/id_rsa

### Go up one directory

    $ ..

### Go up two directories

    $ ...

### Go up more directories

    $ ....
    $ .....
    $ ......

### Backup a file or directory

    $ b script.py
    'script.py' -> 'script_2018-06-16_000000.py'

    $ b project/
    'project' -> 'project_2018-06-16_000000'
    'project/README.md' -> 'project_2018-06-16_000000/README.md'

### Search for files by file name

    $ f filter
    Searching paths and filenames containing "*filter*":
    ./admin/static/admin/js/SelectFilter2.js
    ./admin/templates/admin/filter.html
    ./admin/filters.py
    ./admindocs/templates/admin_doc/template_filter_index.html

### View git status

    $ s
    git status
    On branch master
    Your branch is up to date with 'origin/master'.

    nothing to commit, working tree clean

### View last git diff

    $ dfl
    $ difflast

Keeps two kinds of noisy diff readable. A commit that renumbers a list shows as a word diff, so you see the changed numbers instead of every line removed and re-added. A commit that's mostly reindenting hides its whitespace-only lines. Pass `--full` to turn both off.

### View git log

    $ log

### List git stashes

    $ list
    stash@{0}: On master: work in progress

### Show a git stash

    $ show 0

### Run git pull

    $ pull

### Go up to the root git repository directory

    $ pwd
    /Users/user/.dot-star/tools/vim/color
    $ r
    $ pwd
    /Users/user/.dot-star

### Open the current directory

    $ oo

### Search for files containing text

    $ s "admin.ModelAdmin"
    ./admin.py:26:class GroupAdmin(admin.ModelAdmin):
    ./admin.py:41:class UserAdmin(admin.ModelAdmin):

### Search for files containing text and edit

    $ se "admin.ModelAdmin"
    (file admin.py contains search keyword and is opened)

### Case-sensitive search for files containing text

    $ ss keyword

### Song duration added to `file' command

    $ file "Out of it All by Helen Jane Long.mp3"
    Out of it All by Helen Jane Long.mp3: Audio file with ID3 version 2.4.0, contains:MPEG ADTS, layer III, v2, 160 kbps, 22.05 kHz, Monaural (4,832,126 bytes)
    0:04:38

## macOS hotkeys (Hammerspoon)

`./install.sh` installs Hammerspoon and adds these modules to `~/.hammerspoon/init.lua`, keeping anything already in that file. It reloads Hammerspoon whenever the modules change.

### Apps

| Hotkey | Does |
|--------|------|
| Option(⌥) + C | open Chrome |
| Option(⌥) + D | open a new Ghostty window running `claude` |
| Option(⌥) + F | open Firefox |
| Option(⌥) + G | open `wish` |
| Option(⌥) + I | show or hide Ghostty |
| Option(⌥) + K | open Slack |
| Option(⌥) + M | open VLC |
| Option(⌥) + O | open Finder |
| Option(⌥) + P | open Preview |
| Option(⌥) + S | open Activity Monitor |
| Option(⌥) + V | open MacVim |
| Option(⌥) + Y | open VS Code |
| Option(⌥) + Z | open Zoom |
| F18 | show or hide Ghostty |

### Window layout

Press a side or corner hotkey again to cycle the window through 1/2, 2/3 and 1/3 sizes.

| Hotkey | Does |
|--------|------|
| Ctrl(⌃) + Cmd(⌘) + Q | move to the top-left corner |
| Ctrl(⌃) + Cmd(⌘) + W | move to the top half |
| Ctrl(⌃) + Cmd(⌘) + E | move to the top-right corner |
| Ctrl(⌃) + Cmd(⌘) + A | move to the left half |
| Ctrl(⌃) + Cmd(⌘) + S | fill the screen |
| Ctrl(⌃) + Cmd(⌘) + D | move to the right half |
| Ctrl(⌃) + Cmd(⌘) + Z | move to the bottom-left corner |
| Ctrl(⌃) + Cmd(⌘) + X | move to the bottom half |
| Ctrl(⌃) + Cmd(⌘) + C | move to the bottom-right corner |
| Ctrl(⌃) + Cmd(⌘) + Up | move to the top half |
| Ctrl(⌃) + Cmd(⌘) + Down | move to the bottom half |
| Ctrl(⌃) + Cmd(⌘) + Left | move to the left half |
| Ctrl(⌃) + Cmd(⌘) + Right | move to the right half |
| Option(⌥) + 1 | move to the left third |
| Option(⌥) + 2 | move to the middle third |
| Option(⌥) + 3 | move to the right third |
| Option(⌥) + 4 | move to the left two-thirds |
| Option(⌥) + 5 | move to the right two-thirds |
| Option(⌥) + 6 | center at half width |
| Option(⌥) + 7 | center at two-thirds width |
| Option(⌥) + 8 | move to the third just left of center |
| Option(⌥) + 9 | move to the third just right of center |

### Displays and tabs

| Hotkey | Does |
|--------|------|
| Ctrl(⌃) + Option(⌥) + Cmd(⌘) + Left | move the window to the previous display |
| Ctrl(⌃) + Option(⌥) + Cmd(⌘) + Right | move the window to the next display |
| Ctrl(⌃) + Option(⌥) + Cmd(⌘) + N | move the current tab to a new window (Safari, Chrome, Ghostty) |

### Spaces

| Hotkey | Does |
|--------|------|
| Ctrl(⌃) + Left | move one Space left; from the first Space, wrap to the last |
| Ctrl(⌃) + Right | move one Space right; from the last Space, wrap to the first full-screen Space |
| Fn + Left | move one Space left, like Ctrl(⌃) + Left (replaces Home) |
| Fn + Right | move one Space right, like Ctrl(⌃) + Right (replaces End) |
| Option(⌥) + N | jump to the Space that most needs you next |

### System

| Hotkey | Does |
|--------|------|
| Option(⌥) + B | turn Bluetooth on or off |
| Option(⌥) + W | turn Wi-Fi on or off |

### Always on

- A clock showing Eastern and Pacific time.
- Bars on the screen edges and dots in the title bar show where the current full-screen Space sits in the swipe order.
- Closing a full-screen window takes you to the next full-screen app instead of the desktop.

## Update

    $ dotstar
    $ ./update.sh

The installation and update may be run repeatedly. Neither action will remove nor overwrite files outside the dotstar directory.

## Compatibility
- Mac
- Ubuntu

## Mission

    There should be one-- and preferably only one --command to do it.
