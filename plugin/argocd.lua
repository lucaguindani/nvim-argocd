-- plugin/argocd.lua
-- This file is loaded automatically by Neovim when the plugin is installed

-- Protected call to avoid errors if argocd.lua is missing
local ok, argocd = pcall(require, "argocd")
if not ok then
  vim.notify("Failed to load argocd.nvim plugin", vim.log.levels.ERROR)
  return
end

-- Call setup with default options
argocd.setup()
