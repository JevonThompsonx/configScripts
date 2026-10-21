-- Bootstrap the Neovim plugin and LSP toolchain for a freshly cloned config.
--
-- Usage:
--   nvim --headless -c "luafile /path/to/nvim/bootstrap.lua" -c "qa!"
--
-- This runs inside the user's own Neovim config (that is the point: the
-- config defines the plugins that have to be installed), so the order below
-- matters and mirrors what lazy.nvim and mason.nvim expect:
--
--   1. refresh the mason registry so package metadata is current
--   2. install `tree-sitter-cli`. The LazyVim treesitter build needs it and
--      would otherwise kick off an install that is still running when Neovim
--      exits, which aborts the install ("Neovim is exiting while packages are
--      still installing").
--   3. sync the lazy.nvim plugins (this also rebuilds the treesitter parsers)
--   4. wait for any mason install that the sync started to finish
--
-- Requirements: Neovim >= 0.11.2 (LazyVim v16 requirement) and a working
-- `git`/`curl` for the plugin and package downloads.

local REGISTRY_TIMEOUT_MS = 120000
local INSTALL_TIMEOUT_MS = 900000
local BUSY_POLL_MS = 30000

local function log(msg)
  vim.api.nvim_echo({ { "[bootstrap] " .. msg } }, true, {})
end

---Wait for a predicate, reporting a timeout instead of hanging forever.
---@param predicate fun(): boolean
---@param timeout_ms integer
---@return boolean
local function wait_for(predicate, timeout_ms)
  local ok = vim.wait(timeout_ms, predicate, 200)
  if not ok then
    log(("timed out after %ds"):format(math.floor(timeout_ms / 1000)))
  end
  return ok
end

---@return table? mason-registry
local function mason_registry()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return nil
  end
  return registry
end

---mason.nvim is lazy-loaded by the config, so make sure it is set up before
---its registry is used.
local function load_mason()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    return false
  end
  local loaded = pcall(lazy.load, { plugins = { "mason.nvim" } })
  return loaded
end

local function refresh_registry()
  local registry = mason_registry()
  if not registry then
    log("mason.nvim is not available; skipping the registry refresh")
    return false
  end
  log("refreshing the mason registry")
  local done = false
  registry.refresh(function()
    done = true
  end)
  return wait_for(function()
    return done
  end, REGISTRY_TIMEOUT_MS)
end

---@return string[] names of packages that are currently being installed
local function installing_packages()
  local registry = mason_registry()
  if not registry then
    return {}
  end
  local busy = {}
  for _, pkg in pairs(registry.get_all_packages()) do
    if pkg:is_installing() then
      busy[#busy + 1] = pkg.name
    end
  end
  table.sort(busy)
  return busy
end

---Install a single mason package and wait for it.
---@param name string
---@return boolean
local function install_package(name)
  local registry = mason_registry()
  if not registry then
    return false
  end
  local pkg = registry.get_package(name)
  if not pkg then
    log(("mason does not provide the package %q"):format(name))
    return false
  end
  if pkg:is_installed() then
    return true
  end
  log(("installing %s"):format(name))
  local done, success = false, false
  pkg:install(nil, function(ok)
    success = ok
    done = true
  end)
  wait_for(function()
    return done
  end, INSTALL_TIMEOUT_MS)
  if not success then
    log(("failed to install %s"):format(name))
  end
  return success
end

---Sync the lazy.nvim plugins and wait for the mason installs it triggers.
local function sync_plugins()
  log("syncing lazy.nvim plugins")
  vim.cmd("Lazy! sync")

  local deadline = INSTALL_TIMEOUT_MS
  while deadline > 0 do
    local busy = installing_packages()
    if #busy == 0 then
      return true
    end
    log(("waiting for mason to finish: %s"):format(table.concat(busy, ", ")))
    wait_for(function()
      return #installing_packages() == 0
    end, BUSY_POLL_MS)
    deadline = deadline - BUSY_POLL_MS
  end
  return false
end

local function main()
  if not load_mason() then
    log("lazy.nvim is not available; run the sync manually with :Lazy sync")
    return
  end

  refresh_registry()

  -- The treesitter parser build needs the tree-sitter CLI. Installing it here
  -- keeps the build synchronous.
  install_package("tree-sitter-cli")

  sync_plugins()

  log("bootstrap complete")
end

main()
