return {
  "coder/claudecode.nvim",
  cmd = { "ClaudeCode", "ClaudeCodeFocus" },
  -- Stay fully idle until <leader>a toggles it: no background websocket
  -- server, and "native" avoids requiring snacks.nvim as a dependency.
  opts = {
    auto_start = false,
    terminal = { provider = "native" },
  },
}
