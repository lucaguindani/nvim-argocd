-- lua/api.lua

local Api = {}

local Auth = require("argocd.auth")
local curl = require("plenary.curl")

function Api.request(method, path, body)
  local host = Auth.get_host()
  local token = Auth.get_token()

  if not host or not token then
    vim.notify("Cannot make API request: Not logged in or host/token missing.", vim.log.levels.ERROR)
    return {
      status = 401,
      body = "Not logged in or missing host/token",
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
    Auth.clear_credentials() -- Clear potentially bad credentials
  end

  return res
end

function Api.get_applications()
  return Api.request("get", "/api/v1/applications")
end

function Api.get_application_details(app_name)
  if not app_name or app_name == "" then
    vim.notify("Application name is required for get_application_details", vim.log.levels.ERROR)
    return { status = 400, body = "Application name required" }
  end
  return Api.request("get", "/api/v1/applications/" .. app_name)
end

function Api.update_application_params(app_name, patch_body)
  if not app_name or app_name == "" then
    vim.notify("Application name is required for update_application_params", vim.log.levels.ERROR)
    return { status = 400, body = "Application name required" }
  end
  if not patch_body then
    vim.notify("Patch body is required for update_application_params", vim.log.levels.ERROR)
    return { status = 400, body = "Patch body required" }
  end
  return Api.request("patch", "/api/v1/applications/" .. app_name, patch_body)
end

function Api.sync_application(app_name)
  if not app_name or app_name == "" then
    vim.notify("Application name is required for sync_application", vim.log.levels.ERROR)
    return { status = 400, body = "Application name required" }
  end
  return Api.request("post", "/api/v1/applications/" .. app_name .. "/sync")
end

function Api.delete_application(app_name)
  if not app_name or app_name == "" then
    vim.notify("Application name is required for delete_application", vim.log.levels.ERROR)
    return { status = 400, body = "Application name required" }
  end
  return Api.request("delete", "/api/v1/applications/" .. app_name)
end

return Api
