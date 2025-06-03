local M = {}
local auth = require("argocd.auth")

-- Make API requests to ArgoCD
function M.api_request(method, path, body)
  if not auth.defaults.host or not auth.defaults.token or not path then
    return {
      status = 401,
      body = "Not logged in or missing host/token",
    }
  end

  local curl = require("plenary.curl")
  local url = config.defaults.host .. path
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. config.defaults.token
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

-- Get application status
function M.get_app_status(app_name)
  local res = M.api_request("get", "/api/v1/applications/" .. app_name)
  if res.status == 200 then
    local app = vim.fn.json_decode(res.body)
    return app.status.sync.status
  end
  return nil
end

-- Sync an application
function M.sync_app(app_name)
  local status = M.get_app_status(app_name)
  if status == "Synced" then
    vim.notify("Application " .. app_name .. " is already synced", vim.log.levels.INFO)
    return
  end

  local confirm = vim.fn.confirm("Sync application " .. app_name .. "?", "&Yes\n&No")
  if confirm ~= 1 then
    return
  end

  local res = M.api_request("post", "/api/v1/applications/" .. app_name .. "/sync")

  if res.status == 200 then
    vim.notify("Sync started for " .. app_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to sync: " .. res.body, vim.log.levels.ERROR)
  end
end

-- Delete an application
function M.delete_app(app_name)
  local confirm = vim.fn.confirm("Delete application " .. app_name .. "?", "&Yes\n&No")
  if confirm ~= 1 then
    return
  end

  local res = M.api_request("delete", "/api/v1/applications/" .. app_name)
  if res.status == 200 then
    vim.notify("Application deleted: " .. app_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to delete: " .. res.body, vim.log.levels.ERROR)
  end
end

-- Get application parameters
function M.get_app_parameters(app_name)
  local res = M.api_request("get", "/api/v1/applications/" .. app_name)
  if res.status ~= 200 then
    return nil, "Failed to fetch app: " .. res.body
  end

  local app_data = vim.fn.json_decode(res.body)
  local params = {}
  if app_data.spec and app_data.spec.source and app_data.spec.source.helm and app_data.spec.source.helm.parameters then
    params = app_data.spec.source.helm.parameters
  end
  return params
end

-- Update application parameters
function M.update_app_parameters(app_name, parameters)
  local patch_body = {
    name = app_name,
    patch = vim.fn.json_encode({
      spec = {
        source = {
          helm = {
            parameters = parameters
          }
        }
      }
    }),
    patchType = "merge"
  }

  local res = M.api_request("patch", "/api/v1/applications/" .. app_name, patch_body)
  if res.status == 200 then
    return true, "Parameters updated for " .. app_name
  else
    return false, "Update failed: " .. res.body
  end
end

-- Get all applications
function M.get_applications()
  local res = M.api_request("get", "/api/v1/applications")
  if res.status ~= 200 then
    return nil, "Failed to fetch apps: " .. res.body
  end

  local json = vim.fn.json_decode(res.body)
  local apps = {}

  for i, app in ipairs(json.items or {}) do
    local sync_status = app.status.sync.status or "Unknown"
    local icon = (sync_status == "Synced") and "✓" or "⚠"
    local commit_sha = app.status.sync.revision or "unknown"
    local short_sha = commit_sha:sub(1, 7)
    local branch = app.spec.source.targetRevision or "unknown"

    apps[i] = {
      name = app.metadata.name,
      icon = icon,
      sha = short_sha,
      branch = branch,
      status = sync_status,
    }
  end

  return apps
end

return M
