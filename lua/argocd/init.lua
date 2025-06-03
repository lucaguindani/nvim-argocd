local M = {}

-- Lazy load auth module
function M.lazy_login()
  return require("argocd.auth").lazy_login()
end

function M.clear_credentials()
  return require("argocd.auth").clear_credentials()
end

function M.is_logged_in()
  return require("argocd.auth").is_logged_in()
end

-- Lazy load API functions
function M.api_request(...)
  return require("argocd.api").api_request(...)
end

function M.sync_app(...)
  return require("argocd.api").sync_app(...)
end

function M.delete_app(...)
  return require("argocd.api").delete_app(...)
end

-- Lazy load UI functions
function M.list_apps()
  return require("argocd.ui").list_apps()
end

function M.telescope_apps()
  return require("argocd.ui").telescope_apps()
end

function M.update_app(...)
  return require("argocd.ui").update_app(...)
end

return M
