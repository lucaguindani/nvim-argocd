local auth = require("argocd.auth")
local api = require("argocd.api")
local ui = require("argocd.ui")

return {
  login = auth.login,
  clear_credentials = auth.clear_credentials,
  is_logged_in = auth.is_logged_in,
  api_request = api.api_request,
  sync_app = api.sync_app,
  delete_app = api.delete_app,
  update_app = api.update_app_parameters,
  list_apps = ui.list_apps,
  telescope_apps = ui.telescope_apps,
  update_app = ui.update_app
}
