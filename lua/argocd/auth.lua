-- lua/auth.lua

local Auth = {}

local curl = require("plenary.curl")

local config = {
  host = nil,
  token = nil,
}
local creds_path = vim.fn.stdpath("config") .. "/argocd-credentials.json"
local logged_in = false

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

function Auth.lazy_login(callback)
  if logged_in or (config.token and config.host) then
    vim.notify("Already logged in to ArgoCD", vim.log.levels.INFO)
    if callback and type(callback) == "function" then
      callback()
    end
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
          if callback and type(callback) == "function" then
            callback()
          end
        else
          vim.notify("Login failed: " .. res.body, vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

function Auth.clear_credentials()
  config.host = nil
  config.token = nil
  logged_in = false
  -- Attempt to delete the credentials file
  local ok, err = os.remove(creds_path)
  if ok then
    vim.notify("ArgoCD credentials cleared and file removed.", vim.log.levels.INFO)
  elseif err then -- os.remove returns nil, error message on failure
    -- If file didn't exist, it's not an error for clearing credentials
    local f_exists = io.open(creds_path, "r")
    if f_exists then
        f_exists:close()
        vim.notify("Cleared in-memory ArgoCD credentials. Could not remove credentials file: " .. err, vim.log.levels.WARN)
    else
        vim.notify("ArgoCD credentials cleared. No credentials file to remove.", vim.log.levels.INFO)
    end
  end
end

function Auth.get_host()
  return config.host
end

function Auth.get_token()
  return config.token
end

function Auth.is_logged_in()
  return logged_in
end

-- Load saved credentials on module load
load_credentials()

return Auth
