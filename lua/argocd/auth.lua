-- lua/auth.lua

local Auth = {}

local curl = require("plenary.curl")

local contexts = {}
local current_context = nil
local creds_path = vim.fn.stdpath("config") .. "/argocd-credentials.json"

-- Token refresh threshold (1 hour before expiration)
local TOKEN_REFRESH_THRESHOLD = 3600

--- Get the current active context
function Auth.get_current_context()
  return current_context
end

--- Get all available contexts
function Auth.get_contexts()
  return contexts
end

--- Get credentials for a specific context
---@param context_name string Name of the context
---@return table|nil Credentials table or nil if not found
function Auth.get_context_credentials(context_name)
  return contexts[context_name]
end

--- Set the current active context
---@param context_name string Name of the context to activate
---@return boolean Success status
function Auth.set_current_context(context_name)
  if contexts[context_name] then
    current_context = context_name
    Auth.save_contexts()
    return true
  end
  return false
end

--- Add a new context
---@param context_name string Name of the context
---@param host string ArgoCD host URL
---@return boolean Success status
function Auth.add_context(context_name, host)
  if contexts[context_name] then
    return false
  end
  contexts[context_name] = {
    host = host,
    token = nil,
    logged_in = false,
    token_expires = nil
  }
  
  -- If this is the first context, make it the current context
  if vim.tbl_count(contexts) == 1 then
    current_context = context_name
  end
  
  Auth.save_contexts()
  return true
end

--- Remove a context
---@param context_name string Name of the context to remove
---@return boolean Success status
function Auth.remove_context(context_name)
  if not contexts[context_name] then
    return false
  end
  contexts[context_name] = nil
  if current_context == context_name then
    current_context = nil
  end
  Auth.save_contexts()
  return true
end

--- Clear credentials for a specific context
---@param context_name string Name of the context
function Auth.clear_context_credentials(context_name)
  if contexts[context_name] then
    contexts[context_name].token = nil
    contexts[context_name].token_expires = nil
    contexts[context_name].username = nil
    contexts[context_name].password = nil
    contexts[context_name].logged_in = false
    Auth.save_contexts()
  end
end

--- Clear all credentials
function Auth.clear_all_credentials()
  for _, ctx in pairs(contexts) do
    ctx.token = nil
    ctx.token_expires = nil
    ctx.username = nil
    ctx.password = nil
    ctx.logged_in = false
  end
  current_context = nil
  Auth.save_contexts()
end

--- Save all contexts to file
function Auth.save_contexts()
  local f = io.open(creds_path, "w")
  if f then
    local data = {
      contexts = contexts,
      current_context = current_context
    }
    f:write(vim.fn.json_encode(data))
    f:close()
  end
end

--- Load contexts from file
function Auth.load_contexts()
  local f = io.open(creds_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and data.contexts then
      contexts = data.contexts
      current_context = data.current_context
      
      if not current_context then
        for name, _ in pairs(contexts) do
          current_context = name
          break
        end
      end
      
      for _, ctx in pairs(contexts) do
        ctx.logged_in = ctx.token ~= nil
      end
    end
  end
end

--- Clear credentials for the current context
function Auth.clear_current_credentials()
  local current = Auth.get_current_context()
  if current then
    Auth.clear_context_credentials(current)
    vim.notify(string.format("Credentials cleared for context %s", current), vim.log.levels.INFO)
  else
    vim.notify("No context selected", vim.log.levels.ERROR)
  end
end

--- Get host for current context
function Auth.get_current_host()
  local current = Auth.get_current_context()
  if current then
    local ctx = Auth.get_context_credentials(current)
    return ctx and ctx.host
  end
  return nil
end

--- Get token for current context
function Auth.get_current_token()
  local current = Auth.get_current_context()
  if not current then
    return nil
  end
  
  local ctx = Auth.get_context_credentials(current)
  if not ctx or not ctx.token then
    return nil
  end
  
  -- Check if token is expired or close to expiration
  if ctx.token_expires and vim.fn.localtime() >= ctx.token_expires - TOKEN_REFRESH_THRESHOLD then
    -- Token is expired or close to expiration - attempt to refresh
    vim.notify("Token is expired or close to expiration. Attempting to refresh...", vim.log.levels.INFO)
    
    -- Try to refresh token using existing credentials
    if ctx.username and ctx.password then
      local res = Auth.session_request(ctx.username, ctx.password)
      
      if res.status == 200 then
        local data = vim.fn.json_decode(res.body)
        ctx.token = data.token
        ctx.token_expires = vim.fn.localtime() + 86400
        Auth.save_contexts()
        vim.notify("Token refreshed successfully", vim.log.levels.INFO)
        return ctx.token
      else
        vim.notify("Token refresh failed: " .. res.body, vim.log.levels.ERROR)
        return nil
      end
    end
    
    -- If we can't refresh, return nil to force re-login
    return nil
  end
  
  return ctx.token
end

--- Check if logged in to current context
function Auth.is_logged_in()
  local current = Auth.get_current_context()
  if current then
    local ctx = Auth.get_context_credentials(current)
    return ctx and ctx.logged_in
  end
  return false
end

--- Login to the current context using username and password
function Auth.lazy_login(callback)
  local current = Auth.get_current_context()
  if not current then
    vim.notify("No context selected. Please use :ArgoContextAdd to add a context first.", vim.log.levels.ERROR)
    return
  end

  local ctx = Auth.get_context_credentials(current)
  if ctx and (ctx.logged_in or ctx.token) then
    -- Get token with refresh check
    local token = Auth.get_current_token()
    if token then
      if callback and type(callback) == "function" then
        callback()
      end
      return
    end
  end

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

      -- Store credentials for token refresh
      ctx.username = user
      ctx.password = pass

      local res = Auth.session_request(user, pass)
      
      if res.status == 200 then
        local data = vim.fn.json_decode(res.body)
        ctx.token = data.token
        -- Calculate token expiration time (24h from now)
        ctx.token_expires = vim.fn.localtime() + 86400
        ctx.logged_in = true
        Auth.save_contexts()
        vim.notify("Logged in to ArgoCD context " .. current, vim.log.levels.INFO)
        if callback and type(callback) == "function" then
          callback()
        end
      else
        vim.notify("Login failed: " .. res.body, vim.log.levels.ERROR)
        -- Clear stored credentials on failed login
        ctx.username = nil
        ctx.password = nil
        Auth.save_contexts()
      end
    end)
  end)
end

-- Perform a session request to the login endpoint
function Auth.session_request(username, password)
  local host = Auth.get_current_host()
  return curl.post(host .. "/api/v1/session", {
    body = vim.fn.json_encode({ username = username, password = password }),
    headers = { ["Content-Type"] = "application/json" },
  })
end

-- Load saved contexts on module load
Auth.load_contexts()

return Auth
