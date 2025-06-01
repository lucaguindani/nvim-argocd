-- File: lua/plugins/argocd.lua
-- ArgoCD Plugin for Neovim (Lazy.nvim compatible with Telescope support)

local M = {}
local config = {
  host = nil,
  token = nil,
}
local creds_path = vim.fn.stdpath("config") .. "/argocd-credentials.json"
local logged_in = false
local timer = nil
local buf = nil
local app_names = {}

local function save_credentials()
  local creds = {
    host = config.host,
    token = config.token,
  }
  local f = io.open(creds_path, "w")
  if f then
    f:write(vim.fn.json_encode(creds))
    f:close()
  end
end

local function load_credentials()
  local f = io.open(creds_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, creds = pcall(vim.fn.json_decode, content)
    if ok and creds.host and creds.token then
      config.host = creds.host
      config.token = creds.token
      logged_in = true
    end
  end
end

local function api_request(method, path, body)
  local curl = require("plenary.curl")
  local url = config.host .. path
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. config.token
  }

  local options = {
    url = url,
    method = method,
    headers = headers,
  }

  if body then
    options.body = vim.fn.json_encode(body)
  end

  return curl.request(options)
end

local function lazy_login(callback)
  if logged_in or (config.token and config.host) then
    callback()
    return
  end

  vim.ui.input({ prompt = "ArgoCD API Host (e.g. https://argocd.example.com): " }, function(host)
    if not host or host == "" then
      vim.notify("Host is required", vim.log.levels.ERROR)
      return
    end
    config.host = host
    vim.ui.input({ prompt = "Username: " }, function(user)
      if not user or user == "" then
        vim.notify("Username is required", vim.log.levels.ERROR)
        return
      end
      vim.ui.input({ prompt = "Password: ", secret = true }, function(pass)
        if not pass or pass == "" then
          vim.notify("Password is required", vim.log.levels.ERROR)
          return
        end
        local curl = require("plenary.curl")
        local res = curl.post(config.host .. "/api/v1/session", {
          body = vim.fn.json_encode({ username = user, password = pass }),
          headers = { ["Content-Type"] = "application/json" },
        })
        if res.status == 200 then
          local data = vim.fn.json_decode(res.body)
          config.token = data.token
          logged_in = true
          save_credentials()
          vim.notify("Logged in to ArgoCD", vim.log.levels.INFO)
          callback()
        else
          vim.notify("Login failed: " .. res.body, vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

-- Load saved credentials on plugin load
load_credentials()

function M.list_apps()
  -- Cancel previous timer if any
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end

  local function fetch_and_draw()
    local res = api_request("get", "/api/v1/applications")
    if res.status ~= 200 then
      vim.schedule(function()
        vim.notify("Failed to fetch apps: " .. res.body, vim.log.levels.ERROR)
      end)
      return
    end

    local json = vim.fn.json_decode(res.body)
    local lines = {}
    app_names = {}

    for _, app in ipairs(json.items or {}) do
      local sync_status = app.status.sync.status or "Unknown"
      local icon, color
      if sync_status == "Synced" then
        icon = "✓"
        color = "String"
      else
        icon = "⚠"
        color = "WarningMsg"
      end
      local line = string.format("%s %s", icon, app.metadata.name)
      table.insert(lines, line)
      table.insert(app_names, app.metadata.name)
    end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        if timer then
          timer:stop()
          timer:close()
          timer = nil
        end
        return
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

      for i, _ in ipairs(lines) do
        local sync_status = json.items[i].status.sync.status or "Unknown"
        local hl_group = sync_status == "Synced" and "String" or "WarningMsg"
        vim.api.nvim_buf_add_highlight(buf, -1, hl_group, i - 1, 0, 1)
      end
    end)
  end

  vim.cmd("vsplit")
  vim.cmd("enew")
  buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = "argocd"

  -- <CR> to confirm sync for out-of-sync apps
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      local line_nr = vim.api.nvim_win_get_cursor(0)[1]
      local app_name = app_names[line_nr]
      local res = api_request("get", "/api/v1/applications/" .. app_name)
      if res.status ~= 200 then
        vim.notify("Failed to fetch app status: " .. res.body, vim.log.levels.ERROR)
        return
      end
      local app = vim.fn.json_decode(res.body)
      local app_status = app.status.sync.status or "Unknown"
      if app_status ~= "Synced" then
        vim.ui.select({"No", "Yes"}, {
          prompt = "Sync app '" .. app_name .. "' now?",
        }, function(choice)
          if choice == "Yes" then
            M.sync_app(app_name)
          else
            vim.notify("Sync cancelled", vim.log.levels.INFO)
          end
        end)
      else
        vim.notify(app_name .. " is already synced.", vim.log.levels.INFO)
      end
    end,
  })

  -- First fetch and draw
  fetch_and_draw()

  -- Start timer to refresh every 5 seconds
  timer = vim.loop.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(fetch_and_draw))
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

function M.clear_credentials()
  -- Clear in-memory config
  config.host = nil
  config.token = nil
  logged_in = false

  -- Delete the credentials file if it exists
  local ok, err = os.remove(creds_path)
  if ok then
    vim.notify("ArgoCD credentials cleared", vim.log.levels.INFO)
  else
    if err then
      vim.notify("Error clearing credentials: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("No credentials file to delete", vim.log.levels.INFO)
    end
  end
end

function M.setup()
  vim.api.nvim_create_user_command("ArgoList", function()
    lazy_login(M.list_apps)
  end, {})

  vim.api.nvim_create_user_command("ArgoSync", function(opts)
    lazy_login(function() M.sync_app(opts.args) end)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoLogs", function(opts)
    lazy_login(function() M.logs_app(opts.args) end)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoDelete", function(opts)
    lazy_login(function() M.delete_app(opts.args) end)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoRollback", function(opts)
    lazy_login(function() M.rollback_app(opts.args) end)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoPick", function()
    lazy_login(M.telescope_apps)
  end, {})

  vim.api.nvim_create_user_command("ArgoClearCreds", function()
    M.clear_credentials()
  end, {})
end

return M
