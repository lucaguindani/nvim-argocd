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

  it('should expose the get_current_context function', function()
    assert.is_not_nil(auth_mod.get_current_context, 'get_current_context function should exist.')
    assert.is_function(auth_mod.get_current_context, 'get_current_context should be a function.')
  end)

  it('should expose the get_contexts function', function()
    assert.is_not_nil(auth_mod.get_contexts, 'get_contexts function should exist.')
    assert.is_function(auth_mod.get_contexts, 'get_contexts should be a function.')
  end)

  it('should expose the get_context_credentials function', function()
    assert.is_not_nil(auth_mod.get_context_credentials, 'get_context_credentials function should exist.')
    assert.is_function(auth_mod.get_context_credentials, 'get_context_credentials should be a function.')
  end)

  it('should expose the set_current_context function', function()
    assert.is_not_nil(auth_mod.set_current_context, 'set_current_context function should exist.')
    assert.is_function(auth_mod.set_current_context, 'set_current_context should be a function.')
  end)

  it('should expose the add_context function', function()
    assert.is_not_nil(auth_mod.add_context, 'add_context function should exist.')
    assert.is_function(auth_mod.add_context, 'add_context should be a function.')
  end)

  it('should expose the remove_context function', function()
    assert.is_not_nil(auth_mod.remove_context, 'remove_context function should exist.')
    assert.is_function(auth_mod.remove_context, 'remove_context should be a function.')
  end)

  it('should expose the clear_context_credentials function', function()
    assert.is_not_nil(auth_mod.clear_context_credentials, 'clear_context_credentials function should exist.')
    assert.is_function(auth_mod.clear_context_credentials, 'clear_context_credentials should be a function.')
  end)

  it('should expose the clear_all_credentials function', function()
    assert.is_not_nil(auth_mod.clear_all_credentials, 'clear_all_credentials function should exist.')
    assert.is_function(auth_mod.clear_all_credentials, 'clear_all_credentials should be a function.')
  end)

  it('should expose the save_contexts function', function()
    assert.is_not_nil(auth_mod.save_contexts, 'save_contexts function should exist.')
    assert.is_function(auth_mod.save_contexts, 'save_contexts should be a function.')
  end)

  it('should expose the lazy_login function', function()
    assert.is_not_nil(auth_mod.lazy_login, 'lazy_login function should exist.')
    assert.is_function(auth_mod.lazy_login, 'lazy_login should be a function.')
  end)

  it('should expose the clear_current_credentials function', function()
    assert.is_not_nil(auth_mod.clear_current_credentials, 'clear_current_credentials function should exist.')
    assert.is_function(auth_mod.clear_current_credentials, 'clear_current_credentials should be a function.')
  end)

  it('should expose the get_current_host function', function()
    assert.is_not_nil(auth_mod.get_current_host, 'get_current_host function should exist.')
    assert.is_function(auth_mod.get_current_host, 'get_current_host should be a function.')
  end)

  it('should expose the get_current_token function', function()
    assert.is_not_nil(auth_mod.get_current_token, 'get_current_token function should exist.')
    assert.is_function(auth_mod.get_current_token, 'get_current_token should be a function.')
  end)

  it('should expose the is_logged_in function', function()
    assert.is_not_nil(auth_mod.is_logged_in, 'is_logged_in function should exist.')
    assert.is_function(auth_mod.is_logged_in, 'is_logged_in should be a function.')
  end)
end)