local M = {}
local auth = require("argocd.auth")
local api = require("argocd.api")
local ui = require("argocd.ui")

-- Auth functions
M.lazy_login = auth.lazy_login
M.clear_credentials = auth.clear_credentials
M.is_logged_in = auth.is_logged_in

-- API functions
M.api_request = api.api_request
M.sync_app = api.sync_app
M.delete_app = api.delete_app
M.update_app = api.update_app_parameters

-- UI functions
M.list_apps = ui.list_apps
M.telescope_apps = ui.telescope_apps
M.update_app = ui.update_app

return M
