-- Check Neovim version
local v = vim.version()
if not (v.major > 0 or (v.major == 0 and v.minor >= 7)) then
  vim.notify("[argocd.nvim] requires Neovim >= 0.7.0", vim.log.levels.ERROR)
  return
end

-- Check if argocd is installed and load it
local argocd_ok, argocd = pcall(require, "argocd")
if not argocd_ok then
  vim.notify("[argocd.nvim] failed to load plugin: " .. (argocd or "unknown error"), vim.log.levels.ERROR)
  return
end

-- Check if plenary is installed
local plenary_ok, _ = pcall(require, "plenary")
if not plenary_ok then
  vim.notify("[argocd.nvim] requires plenary", vim.log.levels.ERROR)
  return
end

-- Set up the plugin with default commands
vim.api.nvim_create_user_command("ArgoList", function()
  if not argocd.is_logged_in() then
    vim.notify("[argocd.nvim] Not logged in. Please login first.", vim.log.levels.ERROR)
    return
  end
  argocd.list_apps()
end, {})

vim.api.nvim_create_user_command("ArgoSync", function(opts)
  if not argocd.is_logged_in() then
    vim.notify("[argocd.nvim] Not logged in. Please login first.", vim.log.levels.ERROR)
    return
  end
  argocd.sync_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoDelete", function(opts)
  if not argocd.is_logged_in() then
    vim.notify("[argocd.nvim] Not logged in. Please login first.", vim.log.levels.ERROR)
    return
  end
  argocd.delete_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoUpdate", function(opts)
  if not argocd.is_logged_in() then
    vim.notify("[argocd.nvim] Not logged in. Please login first.", vim.log.levels.ERROR)
    return
  end
  argocd.update_app(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("ArgoPick", function()
  if not argocd.is_logged_in() then
    vim.notify("[argocd.nvim] Not logged in. Please login first.", vim.log.levels.ERROR)
    return
  end
  argocd.telescope_apps()
end, {})

vim.api.nvim_create_user_command("ArgoLogout", function()
  argocd.clear_credentials()
end, {})

-- Add login command
vim.api.nvim_create_user_command("ArgoLogin", function()
  argocd.login()
end, {})
