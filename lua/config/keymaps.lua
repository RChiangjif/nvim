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
