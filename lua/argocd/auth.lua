local M = {}

-- Configuration defaults
M.defaults = {
  host = nil,
  token = nil,
}

-- Credentials file path
M.creds_path = vim.fn.stdpath("config") .. "/argocd-credentials.json"

-- Load saved credentials
function M.load_credentials()
  local f = io.open(M.creds_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, creds = pcall(vim.fn.json_decode, content)
    if ok and creds.host and creds.token then
      M.defaults.host = creds.host
      M.defaults.token = creds.token
      return true
    end
  end
  return false
end

-- Save credentials
function M.save_credentials()
  local creds = {
    host = M.defaults.host,
    token = M.defaults.token,
  }
  local f = io.open(M.creds_path, "w")
  if f then
    f:write(vim.fn.json_encode(creds))
    f:close()
  end
end

-- Check if user is logged in
function M.is_logged_in()
  return M.defaults.host ~= nil and M.defaults.token ~= nil
end

-- Lazy login - attempts to use existing credentials first
function M.lazy_login(callback)
  if M.is_logged_in() then
    if callback then callback() end
    return
  end

  vim.ui.input({
    prompt = "ArgoCD API Host (e.g. https://argocd.example.com): ",
    default = M.defaults.host
  }, function(host)
    if not host or host == "" then
      vim.notify("Host is required", vim.log.levels.ERROR)
      if callback then callback() end
      return
    end
    M.defaults.host = host

    vim.ui.input({ prompt = "Username: " }, function(user)
      if not user or user == "" then
        vim.notify("Username is required", vim.log.levels.ERROR)
        if callback then callback() end
        return
      end

      vim.ui.input({ prompt = "Password: ", secret = true }, function(pass)
        if not pass or pass == "" then
          vim.notify("Password is required", vim.log.levels.ERROR)
          if callback then callback() end
          return
        end

        local curl = require("plenary.curl")
        local res = curl.post(M.defaults.host .. "/api/v1/session", {
          body = vim.fn.json_encode({ username = user, password = pass }),
          headers = { ["Content-Type"] = "application/json" },
        })

        if res.status == 200 then
          local data = vim.fn.json_decode(res.body)
          M.defaults.token = data.token
          M.save_credentials()
          vim.notify("Logged in to ArgoCD", vim.log.levels.INFO)
          if callback then callback() end
        else
          vim.notify("Login failed: " .. res.body, vim.log.levels.ERROR)
          if callback then callback() end
        end
      end)
    end)
  end)
end

-- Clear stored credentials
function M.clear_credentials()
  M.defaults.host = nil
  M.defaults.token = nil
  M.save_credentials()
  vim.notify("Credentials cleared", vim.log.levels.INFO)
end

return M
