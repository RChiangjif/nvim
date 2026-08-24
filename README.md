# nvim

A small Neovim config for competitive programming, running unchanged on macOS
and Windows.

Requires Neovim 0.10 or newer (`vim.system`, `vim.uv`, `vim.fs.joinpath`).

## Install

```sh
# macOS / Linux
git clone https://github.com/RChiangjif/nvim.git ~/.config/nvim
```

```powershell
# Windows
git clone https://github.com/RChiangjif/nvim.git $env:LOCALAPPDATA\nvim
```

Start `nvim`. lazy.nvim bootstraps itself and installs the plugins pinned in
`lazy-lock.json`.

The file explorer is [neiltree](https://github.com/RChiangjif/neiltree),
installed from GitHub like every other plugin - nothing to set up per machine.
Its sidebar opens on startup with the cursor left in your file; `<leader>n`
closes it. Sessions that have no use for a file tree - `nvim -d`, a buffer
piped in on stdin, a git commit message - start without it.

### Optional tools

| Tool | Needed for | Install |
| --- | --- | --- |
| ripgrep | `<leader>fg` live grep | `brew install ripgrep` / `winget install BurntSushi.ripgrep.MSVC` |
| fd | faster `<leader>ff` | `brew install fd` / `winget install sharkdp.fd` |
| g++ / gcc | running C and C++ | Xcode CLT or Homebrew / MSYS2 or MinGW |
| python3 | running Python | python.org or Homebrew |
| claude | `<leader>a` Claude Code | `npm i -g @anthropic-ai/claude-code` |

Compilers are probed at startup, newest first (`g++-16` down to `clang++`), so
a Homebrew version bump needs no edit.

## Keys

Leader is `<Space>`. Press `<leader>k` in nvim for a live cheatsheet — it reads
the real keymap table, so it never goes stale.

| Key | Action |
| --- | --- |
| `<leader>c` | Compile and run the current file |
| `<leader>C` | Same, with no timeout, for a program expected to take minutes |
| `<leader>s` | Stop the running program |
| `<leader>e` / `<C-e>` | Toggle the `inp.txt` / `outp.txt` panes |
| `<leader>k` | Toggle the keymap cheatsheet |
| `<leader>n` | Toggle the neiltree sidebar |
| `<leader>m` | Open neiltree in a floating window |
| `<leader>h` | Open this config in a new tab |
| `<leader>a` | Toggle Claude Code |
| `<leader>p` / `<leader>y` | Paste from / yank to the system clipboard |
| `<leader>ff` `fg` `fb` `fh` | Telescope files, grep, buffers, help |
| `<C-w>` in terminal mode | Window commands from inside any `:terminal` |

## Running a solution

`<leader>c` saves every buffer, compiles the current file, feeds it `inp.txt`
on stdin and writes stdout to `outp.txt`. Both files live **next to the source
file**, not in nvim's working directory. `<leader>e` puts them on screen, and
`outp.txt` refreshes on its own after each run.

Compile errors go to the quickfix list, so `<CR>` jumps straight to the line.
Warnings are suppressed (`-w`); C++ builds with `-std=c++17 -DONPC`.

A run is killed after 10 seconds. Use `<leader>C` when that is genuinely too
short, and `<leader>s` to stop it by hand.

While something is running, the statusline shows a live clock and the key that
stops it — `running 3.2s  <leader>s stops`. It disappears when the run ends.

Everything is executed through `vim.system()` with an argument array rather
than a shell command, which is what makes the same config work on both
platforms: no redirection, no quoting rules, no `./`.

## Layout

```
init.lua              entry point
lua/config/
  platform.lua        every OS-specific decision lives here, and nowhere else
  options.lua         editor options
  keymaps.lua         all key mappings
  autocmds.lua        filetype indents, external-change reload
  lazy.lua            plugin manager bootstrap
  runner.lua          compile / run / I-O panes
  cheatsheet.lua      the <leader>k sidebar
lua/plugins/          one file per plugin group
```

Machine-specific overrides go in `lua/config/local.lua`, which is gitignored
and loaded last. For example, to change the run timeout:

```lua
require("config.runner").timeout_ms = 30000
```
