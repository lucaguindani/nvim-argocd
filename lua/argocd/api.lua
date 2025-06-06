-- lua/api.lua

local Api = {}

local Auth = require("argocd.auth")
local curl = require("plenary.curl")

function Api.request(method, path, body)
  local host = Auth.get_current_host()
  local token = Auth.get_current_token()

  if not host or not token then
    vim.notify("Cannot make API request: Not logged in to current context or host/token missing.", vim.log.levels.ERROR)
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

  -- Check for token expiration or invalid token (common with 401/403)
  if res.status == 401 or res.status == 403 then
    vim.notify("ArgoCD token might be expired or invalid. Please try logging out and logging in again.", vim.log.levels.WARN)
  end

  return res
end

function Api.get_applications()
  return Api.request("get", "/api/v1/applications")
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
    vim.notify("Patch body is required for update_application_params", vim.log.levels.ERROR)
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
    vim.notify("Application name is required", vim.log.levels.ERROR)
    return false, { status = 400, body = "Application name required" }
  end

  local apps_res = Api.get_applications()
  if apps_res.status ~= 200 then
    vim.notify("Failed to fetch applications list", vim.log.levels.ERROR)
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

return Api
