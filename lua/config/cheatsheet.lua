-- A read-only sidebar listing this config's own key mappings.
--
-- The list is built by querying nvim's live keymap table, not from a
-- hand-written copy, so a mapping added anywhere - keymaps.lua or a plugin
-- spec's `keys` block - shows up here on its own and can never drift out of
-- date. The catch is that Neovim 0.11 ships ~40 default mappings that also
-- carry a `desc` ([q, ]b, Y, <C-L>, ...), so "has a desc" is not a usable
-- filter. What actually separates this config's mappings is that they are
-- <leader>-prefixed, plus the handful of control keys listed in EXTRA.

local M = {}

M.min_width = 34
M.max_width = 64

-- Non-leader mappings that belong to this config and should be listed.
local EXTRA = {
  ["<C-E>"] = true,
}

-- Section headings in display order. Each `match` is a list of Lua patterns
-- tested against the raw lhs, where a leading <leader> is a literal space.
-- Anything unmatched collects under "Other", so a new mapping is never
-- silently dropped off the sheet.
local SECTIONS = {
  { name = "Competitive programming", match = { "^ c$", "^ C$", "^ s$", "^ e$", "^<C%-E>$" } },
  { name = "Find", match = { "^ f" } },
  { name = "Files", match = { "^ n$", "^ m$", "^ h$" } },
  { name = "Clipboard", match = { "^ p$", "^ y$" } },
  { name = "AI", match = { "^ o$" } },
  { name = "Help", match = { "^ k$" } },
}

local ns = vim.api.nvim_create_namespace("cheatsheet")

---Turn a raw lhs into something readable: the leader is stored as a literal
---space, which would otherwise render as a mysterious gap.
local function pretty(lhs)
  if lhs:sub(1, 1) == " " then
    return "<leader>" .. lhs:sub(2)
  end
  return lhs
end

---Collect this config's mappings, merging the modes a given lhs is bound in
---so that e.g. <leader>p appears once as "n v" rather than twice.
local function collect()
  local by_lhs, order = {}, {}

  -- Deliberately not "x" or "s": nvim answers those queries with the same
  -- mappings as "v", so including them would only produce duplicates to
  -- filter back out.
  for _, mode in ipairs({ "n", "v", "i" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local lhs = m.lhs
      -- #lhs > 1 drops the bare <leader> placeholder, which is machinery
      -- rather than a command.
      local is_leader = lhs:sub(1, 1) == " " and #lhs > 1
      if m.desc and (is_leader or EXTRA[lhs]) then
        local entry = by_lhs[lhs]
        if not entry then
          entry = { lhs = lhs, desc = m.desc, modes = {} }
          by_lhs[lhs] = entry
          order[#order + 1] = entry
        end
        entry.modes[#entry.modes + 1] = mode
      end
    end
  end

  table.sort(order, function(a, b)
    return a.lhs < b.lhs
  end)
  return order
end

---Bucket the mappings into SECTIONS, keeping section order and dropping
---sections that turned out empty.
local function group(entries)
  local buckets, other = {}, {}
  for _, section in ipairs(SECTIONS) do
    buckets[section.name] = {}
  end

  for _, e in ipairs(entries) do
    local placed = false
    for _, section in ipairs(SECTIONS) do
      for _, pat in ipairs(section.match) do
        if e.lhs:match(pat) then
          table.insert(buckets[section.name], e)
          placed = true
          break
        end
      end
      if placed then
        break
      end
    end
    if not placed then
      other[#other + 1] = e
    end
  end

  local out = {}
  for _, section in ipairs(SECTIONS) do
    if #buckets[section.name] > 0 then
      out[#out + 1] = { name = section.name, entries = buckets[section.name] }
    end
  end
  if #other > 0 then
    out[#out + 1] = { name = "Other", entries = other }
  end
  return out
end

---Render the sheet into display lines plus the highlight spans to apply.
---@return string[] lines, table[] marks, integer width
local function render()
  local sections = group(collect())

  local key_w = 0
  for _, s in ipairs(sections) do
    for _, e in ipairs(s.entries) do
      key_w = math.max(key_w, #pretty(e.lhs))
    end
  end

  local lines, marks = {}, {}

  ---Append one line. `spans` is a list of { col, end_col, hl_group }; passing
  ---a bare string instead highlights the whole line with that group.
  ---@param text string
  ---@param spans string|table[]|nil
  local function add(text, spans)
    lines[#lines + 1] = text
    if type(spans) == "string" then
      spans = { { 0, #text, spans } }
    end
    for _, s in ipairs(spans or {}) do
      marks[#marks + 1] = { row = #lines - 1, col = s[1], end_col = s[2], hl = s[3] }
    end
  end

  add(" KEYMAPS", "Title")
  add("")

  for i, s in ipairs(sections) do
    if i > 1 then
      add("")
    end
    add(" " .. s.name, "Function")
    for _, e in ipairs(s.entries) do
      local key = pretty(e.lhs)
      local modes = table.concat(e.modes, " ")
      local pad = string.rep(" ", key_w - #key)

      local key_start = 2
      local key_end = key_start + #key
      local mode_start = key_end + #pad + 2
      local mode_end = mode_start + #modes

      add(("  %s%s  %-3s  %s"):format(key, pad, modes, e.desc), {
        { key_start, key_end, "Special" },
        { mode_start, mode_end, "Comment" },
      })
    end
  end

  add("")
  add(" q / <Esc>  close", "Comment")

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.max(M.min_width, math.min(M.max_width, width + 2))

  return lines, marks, width
end

---The cheatsheet window in the current tab, if it is showing.
local function find_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "cheatsheet" then
      return win
    end
  end
end

function M.open()
  local lines, marks, width = render()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m.row, m.col, {
      end_col = m.end_col,
      hl_group = m.hl,
    })
  end

  vim.bo[buf].filetype = "cheatsheet"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  -- Two tabs could hold a sheet at once, and a duplicate name is an error.
  pcall(vim.api.nvim_buf_set_name, buf, "cheatsheet://keymaps")

  -- Right-hand side, so it does not fight nvim-tree for the left gutter.
  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, width)

  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.wrap = false
  wo.cursorline = true
  wo.foldcolumn = "0"
  wo.list = false
  -- Survive other splits opening and closing at the original width.
  wo.winfixwidth = true

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true, desc = "Close cheatsheet" })
  end
end

function M.close()
  local win = find_win()
  if win then
    -- Guard the case where it is the only window left in the tab.
    pcall(vim.api.nvim_win_close, win, true)
  end
end

function M.toggle()
  if find_win() then
    return M.close()
  end
  M.open()
end

return M
