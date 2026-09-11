-- Bootstrap lazy.nvim, then load every spec file under lua/plugins/.
-- Adding a plugin later means adding one file there - nothing here changes.

local lazypath = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
local lockfile = vim.fs.joinpath(vim.fn.stdpath("config"), "lazy-lock.json")
local auto_update_key = "_auto_update"

if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end

vim.opt.rtp:prepend(lazypath)

-- lazy.nvim treats every top-level lockfile key as a plugin. Keep our
-- auto-update list in that file for convenience, but hide it from lazy's lock
-- manager and put it back whenever lazy rewrites the file.
local function read_auto_update_plugins()
  local file = io.open(lockfile, "r")
  if not file then
    return {}
  end

  local contents = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, contents)
  if not ok or type(data) ~= "table" then
    return nil, "could not decode lazy-lock.json"
  end

  local plugins = data[auto_update_key]
  if plugins == nil then
    return {}
  end
  if type(plugins) ~= "table" or not vim.islist(plugins) then
    return nil, ("%s must be a JSON list"):format(auto_update_key)
  end

  for _, name in ipairs(plugins) do
    if type(name) ~= "string" then
      return nil, ("every entry in %s must be a plugin name"):format(auto_update_key)
    end
  end

  return plugins
end

local auto_update_plugins, auto_update_error = read_auto_update_plugins()
auto_update_plugins = auto_update_plugins or {}

if auto_update_error then
  vim.schedule(function()
    vim.notify(auto_update_error, vim.log.levels.ERROR, { title = "lazy.nvim auto update" })
  end)
end

local function write_auto_update_plugins(plugins)
  local file = assert(io.open(lockfile, "r"))
  local contents = file:read("*a")
  file:close()

  local entry = ("  %s: %s"):format(vim.json.encode(auto_update_key), vim.json.encode(plugins))
  if contents:match("^%{%s*%}%s*$") then
    contents = "{\n" .. entry .. "\n}\n"
  else
    local replaced
    contents, replaced = contents:gsub("^%{\n", function()
      return "{\n" .. entry .. ",\n"
    end, 1)
    assert(replaced == 1, "unexpected lazy-lock.json format")
  end

  file = assert(io.open(lockfile, "wb"))
  file:write(contents)
  file:close()
end

local lock = require("lazy.manage.lock")
local load_lockfile = lock.load
local update_lockfile = lock.update

lock.load = function(...)
  local result = load_lockfile(...)
  lock.lock[auto_update_key] = nil
  return result
end

lock.update = function(...)
  -- Pick up edits made to the list during this Nvim session before lazy
  -- replaces the lockfile.
  local current = read_auto_update_plugins()
  if current then
    auto_update_plugins = current
  end

  lock.lock[auto_update_key] = nil
  local result = update_lockfile(...)
  write_auto_update_plugins(auto_update_plugins)
  return result
end

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "tokyonight-night" } },
  checker = { enabled = false },
  lockfile = lockfile,
})

if #auto_update_plugins > 0 then
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      vim.schedule(function()
        local configured = require("lazy.core.config").plugins
        local plugins = {}
        local unknown = {}
        local seen = {}

        for _, name in ipairs(auto_update_plugins) do
          if configured[name] and not seen[name] then
            plugins[#plugins + 1] = configured[name]
            seen[name] = true
          elseif not configured[name] then
            unknown[#unknown + 1] = name
          end
        end

        if #unknown > 0 then
          vim.notify(
            "Unknown plugin(s) in " .. auto_update_key .. ": " .. table.concat(unknown, ", "),
            vim.log.levels.WARN,
            { title = "lazy.nvim auto update" }
          )
        end

        if #plugins > 0 then
          require("lazy.manage").update({ plugins = plugins, show = false })
        end
      end)
    end,
  })
end
