-- lua/tests/argocd/init_spec.lua

describe('argocd main module (init.lua)', function()
  local argocd_mod

  before_each(function()
    -- Clear the loaded module to ensure a fresh require for each test
    package.loaded['argocd'] = nil
    argocd_mod = require('argocd')
  end)

  it('should load without errors', function()
    assert.is_not_nil(argocd_mod, 'The argocd module should be loadable.')
  end)

  it('should expose the list_apps function', function()
    assert.is_not_nil(argocd_mod.list_apps, 'list_apps function should exist.')
    assert.is_function(argocd_mod.list_apps, 'list_apps should be a function.')
  end)

  it('should expose the update_app function', function()
    assert.is_not_nil(argocd_mod.update_app, 'update_app function should exist.')
    assert.is_function(argocd_mod.update_app, 'update_app should be a function.')
  end)

  it('should expose the sync_app function', function()
    assert.is_not_nil(argocd_mod.sync_app, 'sync_app function should exist.')
    assert.is_function(argocd_mod.sync_app, 'sync_app should be a function.')
  end)

  it('should expose the delete_app function', function()
    assert.is_not_nil(argocd_mod.delete_app, 'delete_app function should exist.')
    assert.is_function(argocd_mod.delete_app, 'delete_app should be a function.')
  end)
end)
