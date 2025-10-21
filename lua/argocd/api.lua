-- lua/api.lua

local Api = {}

local Auth = require("argocd.auth")
local curl = require("plenary.curl")
local notify_ok, notify = pcall(require, "notify")
if not notify_ok then
    notify = vim.notify
end

-- Perform a tokenized request to the ArgoCD API
function Api.request(method, path, body)
  local host = Auth.get_current_host()
  local token = Auth.get_current_token()

  if not host or not token then
    notify("Cannot make API request: Not logged in to current context or host/token missing.", "ERROR", { title = "Nvim-ArgoCD" })
    return {
      status = 401,
      body = "Not logged in to current context or missing host/token",
    }
  end

  local url = host .. path
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. token
  }

  local options = {
    url = url,
    method = method,
    headers = headers,
  }

  if body then
    options.body = vim.fn.json_encode(body)
  end

  -- Perform the request
  local res = curl.request(options)

  -- If token expired (401), refresh
  if res.status == 401 then
    Auth.clear_current_credentials()
    -- Refresh token
    Auth.lazy_login()
  end

  if res.status == 401 then
    notify("Failed to refresh token. Please try logging out and logging in again.", "ERROR", { title = "Nvim-ArgoCD" })
  end

  return res
end

function Api.get_applications()
  return Api.request("get", "/api/v1/applications")
end

function Api.refresh_application(app_name)
  return Api.request("get", "/api/v1/applications/" .. app_name .. "?refresh=hard")
end

function Api.get_application_details(app_name)
  local exists, err = Api.check_application_exists(app_name)
  if not exists then
    return err
  end

  return Api.request("get", "/api/v1/applications/" .. app_name)
end

function Api.update_application_params(app_name, patch_body)
  if not patch_body then
    notify("Patch body is required for update_application_params", "ERROR", { title = "ArgoUpdate" })
    return { status = 400, body = "Patch body required" }
  end

  local exists, err = Api.check_application_exists(app_name)
  if not exists then
    return err
  end

  return Api.request("patch", "/api/v1/applications/" .. app_name, patch_body)
end

function Api.sync_application(app_name)
  local exists, err = Api.check_application_exists(app_name)
  if not exists then
    return err
  end

  return Api.request("post", "/api/v1/applications/" .. app_name .. "/sync")
end

function Api.delete_application(app_name)
  local exists, err = Api.check_application_exists(app_name)
  if not exists then
    return err
  end

  return Api.request("delete", "/api/v1/applications/" .. app_name)
end

function Api.check_application_exists(app_name)
  if not app_name or app_name == "" then
    notify("Application name is required", vim.log.levels.ERROR, { title = "Nvim-ArgoCD" })
    return false, { status = 400, body = "Application name required" }
  end

  local apps_res = Api.get_applications()
  if apps_res.status ~= 200 then
    notify("Failed to fetch applications list", vim.log.levels.ERROR, { title = "Nvim-ArgoCD" })
    return false, { status = 400, body = "Failed to fetch applications list" }
  end

  local apps = vim.fn.json_decode(apps_res.body)
  local app_exists = false
  for _, app in ipairs(apps.items or {}) do
    if app.metadata.name == app_name then
      app_exists = true
      break
    end
  end

  if not app_exists then
    return false, { status = 404, body = "Application not found" }
  end

  return true, nil
end

function Api.get_application_helm_params(app_name)
  local exists, err = Api.check_application_exists(app_name)
  if not exists then
    return err
  end

  -- First get application details to extract source configuration
  local app_res = Api.get_application_details(app_name)
  if app_res.status ~= 200 then
    return app_res
  end

  local app_data = vim.fn.json_decode(app_res.body)
  local source = app_data.spec and app_data.spec.source
  if not source then
    return { status = 400, body = "Application source not found" }
  end

  -- Check if it's a Helm application
  if not source.chart and not source.helm then
    return { status = 400, body = "Application is not a Helm application or does not have Helm configuration" }
  end

  -- Get the repoURL
  local repo_url = source.repoURL
  if not repo_url then
    return { status = 400, body = "Repository URL not found in application source" }
  end

  -- URL encode the repository URL for use in the path
  -- Replace special characters with percent-encoded equivalents
  local encoded_repo_url = repo_url:gsub("([^%w _%%%-%.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  encoded_repo_url = encoded_repo_url:gsub(" ", "+")

  -- Build request body for app details
  local request_body = {
    source = source,
    appName = app_name,
    appProject = app_data.spec.project or "default"
  }

  -- Make request to get app details with all parameters
  return Api.request("post", "/api/v1/repositories/" .. encoded_repo_url .. "/appdetails", request_body)
end

return Api
