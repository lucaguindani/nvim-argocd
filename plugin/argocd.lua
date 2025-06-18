-- plugin/argocd.lua
-- This file is loaded automatically by Neovim when the plugin is installed

-- Check Neovim version
local v = vim.version()
if not (v.major > 0 or (v.major == 0 and v.minor >= 7)) then
  vim.notify("[argocd.nvim] requires Neovim >= 0.7.0", vim.log.levels.ERROR)
  return
end

-- Check if argocd is installed and load it
local argocd_ok, argocd = pcall(require, "argocd")
if not argocd_ok then
  vim.notify("[argocd.nvim] failed to load plugin", vim.log.levels.ERROR)
  return
end

-- Check if plenary is installed
local plenary_ok, _ = pcall(require, "plenary")
if not plenary_ok then
  vim.notify("[argocd.nvim] plenary.nvim is not installed!", vim.log.levels.ERROR)
end

-- Check if notify is installed
local notify_ok, notify = pcall(require, "notify")
if not notify_ok then
  notify = vim.notify
  vim.notify("[argocd.nvim] notify.nvim is not installed!", vim.log.levels.INFO)
else
  notify.setup({
    render = "default",
    stages = "fade",
    timeout = 3500,
  })
end

-- Set up the plugin with default commands

vim.api.nvim_create_user_command("ArgoList", function()
  argocd.list_apps()
end, {})

vim.api.nvim_create_user_command("ArgoSync", function(opts)
  argocd.sync_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoRefresh", function(opts)
  argocd.refresh_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoDelete", function(opts)
  argocd.delete_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoUpdate", function(opts)
  argocd.update_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoPick", function()
  argocd.telescope_apps()
end, {})

vim.api.nvim_create_user_command("ArgoLogin", function()
  argocd.lazy_login()
end, {})

vim.api.nvim_create_user_command("ArgoLogout", function()
  argocd.clear_credentials()
end, {})

vim.api.nvim_create_user_command("ArgoContextList", function()
  argocd.list_contexts()
end, {})

vim.api.nvim_create_user_command("ArgoContextAdd", function(opts)
  local args = vim.split(opts.args, " ", { plain = true })
  if #args ~= 2 then
    notify("Usage: :ArgoContextAdd <name> <host>", vim.log.levels.ERROR, { title = "ArgoContextAdd" })
    return
  end
  argocd.add_context(args[1], args[2])
end, { nargs = "*" })

vim.api.nvim_create_user_command("ArgoContextSwitch", function(opts)
  if opts.args == "" then
    notify("Usage: :ArgoContextSwitch <name>", vim.log.levels.ERROR, { title = "ArgoContextSwitch" })
    return
  end
  argocd.switch_context(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoContextRemove", function(opts)
  if opts.args == "" then
    notify("Usage: :ArgoContextRemove <name>", vim.log.levels.ERROR, { title = "ArgoContextRemove" })
    return
  end
  argocd.remove_context(opts.args)
end, { nargs = 1 })
