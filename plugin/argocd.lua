-- plugin/argocd.lua
-- This file is loaded automatically by Neovim when the plugin is installed

-- Neovim version check
local v = vim.version()
if not (v.major > 0 or (v.major == 0 and v.minor >= 7)) then
  vim.notify("[argocd.nvim] Requires Neovim >= 0.7.0", vim.log.levels.ERROR)
  return
end

-- Check if the argocd.nvim plugin is installed
local ok, argocd = pcall(require, "argocd")
if not ok then
  vim.notify("[argocd.nvim] failed to load plugin", vim.log.levels.ERROR)
  return
end

-- Set up the plugin with default commands and options

vim.api.nvim_create_user_command("ArgoList", function()
  argocd.lazy_login(argocd.list_apps)
end, {})

vim.api.nvim_create_user_command("ArgoSync", function(opts)
  argocd.lazy_login(function() argocd.sync_app(opts.args) end)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoDelete", function(opts)
  argocd.lazy_login(function() argocd.delete_app(opts.args) end)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoPick", function()
  argocd.lazy_login(argocd.telescope_apps)
end, {})

vim.api.nvim_create_user_command("ArgoLogout", function()
  argocd.clear_credentials()
end, {})
