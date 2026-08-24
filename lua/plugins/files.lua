return {
  {
    "RChiangjif/neiltree",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    config = function(_, opts)
      require("neiltree").setup(opts)

      local group = vim.api.nvim_create_augroup("neiltree_auto_open", { clear = true })

      -- `... | nvim -` reads the buffer off stdin; there is no file tree
      -- worth showing next to it, and VimEnter alone cannot tell.
      vim.api.nvim_create_autocmd("StdinReadPre", {
        group = group,
        callback = function()
          vim.g.neiltree_read_stdin = true
        end,
      })

      -- Open the sidebar on startup, then hand focus straight back so the
      -- session still begins in the file you asked for.
      vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        callback = function()
          -- Only for an ordinary editing session: not `nvim -d`, not a
          -- piped buffer, not a scratch/help buffer, and not the throwaway
          -- message buffer git hands $EDITOR.
          local skip_ft = { gitcommit = true, gitrebase = true }
          if
            vim.g.neiltree_read_stdin
            or vim.wo.diff
            or vim.bo.buftype ~= ""
            or skip_ft[vim.bo.filetype]
          then
            return
          end

          local win = vim.api.nvim_get_current_win()
          require("neiltree").toggle_sidebar()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
          end
        end,
      })
    end,
  },
}
