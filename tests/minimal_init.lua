-- Get the root directory of the plugin (nvim-argocd)
local script_path = vim.api.nvim_eval('expand("<sfile>:p")')
local plugin_root = vim.fn.fnamemodify(script_path, ':h:h')

-- Determine Plenary's path and add it to runtimepath
local data_plenary_path = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
local config_plenary_path = vim.fn.stdpath('config') .. '/lazy/plenary.nvim'
local actual_plenary_path

if vim.fn.isdirectory(data_plenary_path) == 1 then
  actual_plenary_path = data_plenary_path
elseif vim.fn.isdirectory(config_plenary_path) == 1 then
  actual_plenary_path = config_plenary_path
else
  vim.api.nvim_err_writeln("Plenary not found at expected lazy.nvim paths. Ensure Plenary is installed via lazy.nvim.")
end

local new_paths = {}

if actual_plenary_path then
  vim.opt.runtimepath:prepend(actual_plenary_path)
  table.insert(new_paths, actual_plenary_path .. '/lua/?.lua')
  table.insert(new_paths, actual_plenary_path .. '/lua/?/init.lua')
end

-- Add the plugin's 'lua' directory to our list of new paths
table.insert(new_paths, plugin_root .. '/lua/?.lua')
table.insert(new_paths, plugin_root .. '/lua/?/init.lua')

-- Prepend all collected new paths to the original package.path
if #new_paths > 0 then
  package.path = table.concat(new_paths, ';') .. ';' .. package.path
else
  package.path = package.path
end

-- Source Plenary's plugin scripts to define commands
vim.cmd('runtime plugin/plenary.vim')
vim.cmd('runtime after/plugin/plenary.vim')
