-- lua/tests/argocd/auth_spec.lua

describe('argocd.auth module', function()
  local auth_mod

  before_each(function()
    -- Clear the loaded module to ensure a fresh require for each test
    package.loaded['argocd.auth'] = nil
    auth_mod = require('argocd.auth')
  end)

  it('should load without errors', function()
    assert.is_not_nil(auth_mod, 'The auth module should be loadable.')
  end)

  it('should expose the lazy_login function', function()
    assert.is_not_nil(auth_mod.lazy_login, 'lazy_login function should exist.')
    assert.is_function(auth_mod.lazy_login, 'lazy_login should be a function.')
  end)

  it('should expose the clear_credentials function', function()
    assert.is_not_nil(auth_mod.clear_credentials, 'clear_credentials function should exist.')
    assert.is_function(auth_mod.clear_credentials, 'clear_credentials should be a function.')
  end)

  it('should expose the get_host function', function()
    assert.is_not_nil(auth_mod.get_host, 'get_host function should exist.')
    assert.is_function(auth_mod.get_host, 'get_host should be a function.')
  end)

  it('should expose the get_token function', function()
    assert.is_not_nil(auth_mod.get_token, 'get_token function should exist.')
    assert.is_function(auth_mod.get_token, 'get_token should be a function.')
  end)

  it('should expose the is_logged_in function', function()
    assert.is_not_nil(auth_mod.is_logged_in, 'is_logged_in function should exist.')
    assert.is_function(auth_mod.is_logged_in, 'is_logged_in should be a function.')
  end)
end)