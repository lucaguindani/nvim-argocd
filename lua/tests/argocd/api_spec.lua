-- lua/tests/argocd/api_spec.lua

describe('argocd.api module', function()
  local api_mod

  before_each(function()
    -- Clear the loaded module to ensure a fresh require for each test
    package.loaded['argocd.api'] = nil
    api_mod = require('argocd.api')
  end)

  it('should load without errors', function()
    assert.is_not_nil(api_mod, 'The api module should be loadable.')
  end)

  it('should expose the request function', function()
    assert.is_not_nil(api_mod.request, 'request function should exist.')
    assert.is_function(api_mod.request, 'request should be a function.')
  end)

  it('should expose the get_applications function', function()
    assert.is_not_nil(api_mod.get_applications, 'get_applications function should exist.')
    assert.is_function(api_mod.get_applications, 'get_applications should be a function.')
  end)

  it('should expose the get_application_details function', function()
    assert.is_not_nil(api_mod.get_application_details, 'get_application_details function should exist.')
    assert.is_function(api_mod.get_application_details, 'get_application_details should be a function.')
  end)

  it('should expose the update_application_params function', function()
    assert.is_not_nil(api_mod.update_application_params, 'update_application_params function should exist.')
    assert.is_function(api_mod.update_application_params, 'update_application_params should be a function.')
  end)

  it('should expose the sync_application function', function()
    assert.is_not_nil(api_mod.sync_application, 'sync_application function should exist.')
    assert.is_function(api_mod.sync_application, 'sync_application should be a function.')
  end)

  it('should expose the delete_application function', function()
    assert.is_not_nil(api_mod.delete_application, 'delete_application function should exist.')
    assert.is_function(api_mod.delete_application, 'delete_application should be a function.')
  end)
end)
