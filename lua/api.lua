-- File: lua/api.lua
-- ArgoCD API request handling

local M = {}

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
    method = method,
    url = url,
    headers = headers,
  }

  if body then
    options.body = vim.fn.json_encode(body)
  end

  local res = curl.request(options)
  return {
    status = res.status,
    body = res.body,
  }
end

-- Export the function
M.api_request = api_request

return M
