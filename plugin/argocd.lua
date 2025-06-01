-- plugin/argocd.lua
-- This file is loaded automatically by Neovim when the plugin is installed

local ok, argocd = pcall(require, "argocd")
if not ok then
  vim.notify("Failed to load argocd.nvim plugin", vim.log.levels.ERROR)
  return
end

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
