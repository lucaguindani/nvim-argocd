-- File: lua/plugins/argocd.lua
-- ArgoCD Plugin for Neovim (Lazy.nvim compatible with Telescope support)

local M = {}
local config = {
  host = nil,
  token = nil,
}
local creds_path = vim.fn.stdpath("config") .. "/argocd-credentials.json"
local logged_in = false
local app_list_timer = nil
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
  if not config.host or not config.token or not path then
    return {
      status = 401,
      body = "Not logged in or missing host/token",
    }
  end

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
    app_names = {}

    for i, app in ipairs(json.items or {}) do
      local sync_status = app.status.sync.status or "Unknown"
      local icon = (sync_status == "Synced") and "✓" or "⚠"
      local commit_sha = app.status.sync.revision or "unknown"
      local short_sha = commit_sha:sub(1, 7)
      local branch = app.spec.source.targetRevision or "unknown"

      app_names[i] = {
        name = app.metadata.name,
        icon = icon,
        sha = short_sha,
        branch = branch,
        status = sync_status,
      }
    end

    local function draw_lines()
      local lines = {}
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

      for i, app in ipairs(app_names) do
        -- Get status icon and highlight group
        local status_icon, status_hl
        if app.status == "Synced" then
          status_icon = status_icon or "✓"
          status_hl = status_hl or "String"
        else
          status_icon = status_icon or "⚠"
          status_hl = status_hl or "WarningMsg"
        end

        -- Build line: status icon + space + app name [+ branch and sha if current line]
        local base = string.format("%s %s", status_icon, app.name)
    
        if i == cursor_line then
          base = base .. string.format(" (%s %s)", app.branch, app.sha)
        end
    
        lines[i] = base
      end
    
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    
      for i, app in ipairs(app_names) do
        -- Highlight status icon (1 char usually)
        vim.api.nvim_buf_add_highlight(buf, -1, (app.status == "Synced") and "String" or "WarningMsg", i - 1, 0, 1)
    
        -- Highlight app name (starts at col 2)
        local name_start = 2
        vim.api.nvim_buf_add_highlight(buf, -1, "Normal", i - 1, name_start, name_start + #app.name)
    
        -- Highlight branch and sha on current line as comment
        if i == cursor_line then
          local comment_pos = lines[i]:find("%(")
          if comment_pos then
            vim.api.nvim_buf_add_highlight(buf, -1, "Comment", i - 1, comment_pos - 1, -1)
          end
        end
      end
    end

    vim.schedule(draw_lines)

    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = buf,
      callback = function()
        vim.schedule(draw_lines)
      end,
      desc = "Highlight branch and SHA on current line",
    })
  end

  vim.cmd("vsplit")
  vim.cmd("enew")
  buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = "argocd"

  -- Disable orange highlight on line number for this buffer
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("highlight CursorLineNr NONE")
  end)

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      local line_nr = vim.api.nvim_win_get_cursor(0)[1]
      local app = app_names[line_nr]
      if not app then return end

      local res = api_request("get", "/api/v1/applications/" .. app.name)
      if res.status ~= 200 then
        vim.notify("Failed to fetch app status: " .. res.body, vim.log.levels.ERROR)
        return
      end
      local app_data = vim.fn.json_decode(res.body)
      local app_status = app_data.status.sync.status or "Unknown"
      if app_status ~= "Synced" then
        vim.ui.select({"No", "Yes"}, {
          prompt = "Sync app '" .. app.name .. "' now?",
        }, function(choice)
          if choice == "Yes" then
            M.sync_app(app.name)
          else
            vim.notify("Sync cancelled", vim.log.levels.INFO)
          end
        end)
      else
        vim.notify(app.name .. " is already synced.", vim.log.levels.INFO)
      end
    end,
  })

  fetch_and_draw()

  -- Start the timer and save the handle
  app_list_timer = uv.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(fetch_and_draw))

  -- Stop timer when buffer is unloaded
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload", "WinClosed" }, {
    buffer = buf,
    once = true,
    callback = function()
      if app_list_timer then
        app_list_timer:stop()
        app_list_timer:close()
        app_list_timer = nil
      end
    end,
  })
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

function M.telescope_apps()
  local has_telescope = pcall(require, "telescope")

  if not has_telescope then
    -- You can notify the user or return a message table for the picker
    vim.notify("[nvim-argocd] telescope.nvim is not installed!", vim.log.levels.WARN)
    return nil -- or return a dummy function/table if needed
  end

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

  vim.api.nvim_create_user_command("ArgoDelete", function(opts)
    lazy_login(function() M.delete_app(opts.args) end)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoPick", function()
    lazy_login(M.telescope_apps)
  end, {})

  vim.api.nvim_create_user_command("ArgoClearCreds", function()
    M.clear_credentials()
  end, {})
end

return M
