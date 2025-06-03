local M = {}

-- Load auth module and initialize
local auth = require("argocd.auth")
auth.load_credentials()

-- Export public functions from auth module
M.lazy_login = auth.lazy_login
M.clear_credentials = auth.clear_credentials
M.is_logged_in = auth.is_logged_in

-- Export public functions from api module
M.api_request = require("argocd.api").api_request
M.sync_app = require("argocd.api").sync_app
M.delete_app = require("argocd.api").delete_app

-- Export public functions from ui module
M.list_apps = require("argocd.ui").list_apps
M.telescope_apps = require("argocd.ui").telescope_apps
M.update_app = require("argocd.ui").update_app

return M
