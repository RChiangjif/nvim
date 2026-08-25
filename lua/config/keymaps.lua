local P = require("config.platform")
local runner = require("config.runner")
local cheatsheet = require("config.cheatsheet")

local map = vim.keymap.set

-- Free <Space> so it can act purely as <leader>.
map({ "n", "v" }, "<Space>", "<Nop>", { desc = "leader placeholder" })

-- System clipboard
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map("v", "<leader>y", '"+y', { desc = "Yank to system clipboard" })

-- Config. stdpath("config") resolves to ~/.config/nvim on macOS and
-- %LOCALAPPDATA%\nvim on Windows, so this one mapping works on both.
map("n", "<leader>h", function()
  vim.cmd("tabedit " .. vim.fn.fnameescape(P.config_dir))
end, { desc = "Open nvim config directory in a new tab" })

-- Tabs
map("n", "<leader>t", "<CMD>tabnext<CR>", { desc = "Go to next tab" })

-- Move between windows first, then continue into the adjacent tab when the
-- current window is already at the left or right edge.
local function move_window_or_tab(direction, tab_command)
  local win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. direction)
  if vim.api.nvim_get_current_win() == win then
    vim.cmd(tab_command)
  end
end

local function move_left()
  move_window_or_tab("h", "tabprevious")
end

local function move_right()
  move_window_or_tab("l", "tabnext")
end

map("n", "<C-w>h", move_left, { desc = "Window left or previous tab" })
map("n", "<C-w>l", move_right, { desc = "Window right or next tab" })

-- File explorer
map("n", "<leader>n", "<CMD>Neiltree --sidebar<CR>", { desc = "Toggle neiltree sidebar" })
map("n", "<leader>m", "<CMD>Neiltree --float<CR>", { desc = "Open neiltree (float)" })

-- Competitive programming
-- Both keys toggle; <C-e> is the quick one, <leader>e the mnemonic. Toggling
-- rather than opening also stops a second press from stacking duplicate panes.
-- <C-e> normally scrolls the view down one line; the toggle takes it over.
map("n", "<leader>e", runner.toggle_io_panes, { desc = "Toggle inp.txt / outp.txt panes" })
map("n", "<C-e>", runner.toggle_io_panes, { desc = "Toggle inp.txt / outp.txt panes" })
map("n", "<leader>c", runner.run, { desc = "Compile and run current file" })
map("n", "<leader>C", function()
  runner.run({ untimed = true })
end, { desc = "Compile and run with no timeout" })
map("n", "<leader>s", runner.stop, { desc = "Stop the running program" })

-- Keymap cheatsheet sidebar. Lists itself too, by virtue of having a desc.
map("n", "<leader>k", cheatsheet.toggle, { desc = "Toggle keymap cheatsheet" })

-- Claude Code terminal. auto_start = false (see plugins/claudecode.lua) keeps
-- it fully idle until this toggles the window open.
map("n", "<leader>a", "<CMD>ClaudeCode<CR>", { desc = "Toggle Claude Code" })

-- Terminal mode intercepts <C-w> as a literal keystroke, unlike normal mode
-- where it starts a window command. Escaping to normal mode first restores
-- the usual <C-w> h/j/k/l/w behavior from inside any :terminal buffer,
-- including the Claude Code window.
map("t", "<C-w>", [[<C-\><C-n><C-w>]], { desc = "Window commands from terminal mode" })
map("t", "<C-w>h", function()
  vim.cmd("stopinsert")
  move_left()
end, { desc = "Window left or previous tab" })
map("t", "<C-w>l", function()
  vim.cmd("stopinsert")
  move_right()
end, { desc = "Window right or next tab" })

-- Keep shell completion available even if the terminal input path consumes
-- <Tab> before it reaches the job.
map("t", "<Tab>", function()
  vim.api.nvim_chan_send(vim.b.terminal_job_id, "\t")
end, { desc = "Complete in terminal" })
