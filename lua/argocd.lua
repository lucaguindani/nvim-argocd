-- File: lua/plugins/argocd.lua
-- ArgoCD Plugin for Neovim (Lazy.nvim compatible with Telescope support)

local M = {}
local config = {
  host = nil,
  token = nil,
}

local function api_request(method, path, body)
  local curl = require("plenary.curl")
  local url = config.host .. path
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. config.token
  }

  local options = {
    method = method,
    headers = headers,
  }

  if body then
    options.body = vim.fn.json_encode(body)
  end

  return curl.request(url, options)
end

function M.list_apps()
  local res = api_request("get", "/api/v1/applications")
  if res.status == 200 then
    local json = vim.fn.json_decode(res.body)
    local apps = {}
    for _, app in ipairs(json.items or {}) do
      table.insert(apps, app.metadata.name)
    end
    vim.cmd("vsplit")
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, apps)
    vim.bo.filetype = "argocd"
  else
    vim.notify("Failed to fetch apps: " .. res.body, vim.log.levels.ERROR)
  end
end

function M.sync_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoSync <app-name>", vim.log.levels.WARN)
    return
  end
  local res = api_request("post", "/api/v1/applications/" .. app_name .. "/sync")
  if res.status == 200 then
    vim.notify("Sync triggered for " .. app_name, vim.log.levels.INFO)
  else
    vim.notify("Sync failed: " .. res.body, vim.log.levels.ERROR)
  end
end

function M.diff_app(app_name)
  vim.notify("Diff API not supported directly. Use CLI fallback or Argo UI.", vim.log.levels.INFO)
end

function M.logs_app(app_name)
  vim.notify("Fetching logs via kubectl: " .. app_name, vim.log.levels.INFO)
  local cmd = {"kubectl", "logs", "deployment/" .. app_name, "--tail=50"}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        vim.cmd("vsplit")
        vim.cmd("enew")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
        vim.bo.filetype = "log"
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end
  })
end

function M.delete_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoDelete <app-name>", vim.log.levels.WARN)
    return
  end
  vim.ui.select({"No", "Yes"}, {
    prompt = "Are you sure you want to delete " .. app_name .. "?",
  }, function(choice)
    if choice == "Yes" then
      local res = api_request("delete", "/api/v1/applications/" .. app_name)
      if res.status == 200 then
        vim.notify("Deleted " .. app_name, vim.log.levels.INFO)
      else
        vim.notify("Delete failed: " .. res.body, vim.log.levels.ERROR)
      end
    end
  end)
end

function M.rollback_app(app_name)
  vim.notify("Rollback not supported via Argo API directly. Use CLI or Argo UI.", vim.log.levels.INFO)
end

function M.telescope_apps()
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local res = api_request("get", "/api/v1/applications")
  if res.status ~= 200 then
    vim.notify("Failed to fetch apps: " .. res.body, vim.log.levels.ERROR)
    return
  end

  local json = vim.fn.json_decode(res.body)
  local apps = {}
  for _, app in ipairs(json.items or {}) do
    table.insert(apps, app.metadata.name)
  end

  pickers.new({}, {
    prompt_title = 'ArgoCD Apps',
    finder = finders.new_table {
      results = apps,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<C-s>', function()
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.sync_app(selection[1])
        end
      end)
      map('i', '<C-x>', function()
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.delete_app(selection[1])
        end
      end)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.sync_app(selection[1])
        end
      end)
      return true
    end
  }):find()
end

function M.setup()
  vim.ui.input({ prompt = "ArgoCD API Host (e.g. https://argocd.example.com): " }, function(host)
    config.host = host
    vim.ui.input({ prompt = "Username: " }, function(user)
      vim.ui.input({ prompt = "Password: ", secret = true }, function(pass)
        local curl = require("plenary.curl")
        local res = curl.post(config.host .. "/api/v1/session", {
          body = vim.fn.json_encode({ username = user, password = pass }),
          headers = { ["Content-Type"] = "application/json" },
        })
        if res.status == 200 then
          local data = vim.fn.json_decode(res.body)
          config.token = data.token
          vim.notify("Logged in to ArgoCD", vim.log.levels.INFO)
        else
          vim.notify("Login failed: " .. res.body, vim.log.levels.ERROR)
        end
      end)
    end)
  end)

  vim.api.nvim_create_user_command("ArgoList", M.list_apps, {})
  vim.api.nvim_create_user_command("ArgoSync", function(opts)
    M.sync_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoDiff", function(opts)
    M.diff_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoLogs", function(opts)
    M.logs_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoDelete", function(opts)
    M.delete_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoRollback", function(opts)
    M.rollback_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoPick", M.telescope_apps, {})
end

return M
