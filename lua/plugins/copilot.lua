return {
  -- Run :Copilot setup once per machine.
  "github/copilot.vim",
  event = "InsertEnter",
  -- Start every session with Copilot off; <leader>o turns it on when wanted.
  -- `init` runs at startup, before the plugin itself loads on InsertEnter.
  -- g:copilot_enabled is exactly what `:Copilot disable` sets, so the toggle
  -- reads this as the genuine starting state rather than fighting it.
  init = function()
    vim.g.copilot_enabled = 0
  end,
}
