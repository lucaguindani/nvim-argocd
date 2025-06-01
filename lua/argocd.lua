-- File: lua/plugins/argocd.lua
-- ArgoCD Plugin for Neovim (Lazy.nvim compatible with Telescope support)

local M = {}

local function run_cmd(cmd, on_success, opts)
  opts = opts or {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        on_success(data)
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end
  })
end

function M.list_apps()
  run_cmd({"argocd", "app", "list"}, function(data)
    vim.cmd("vsplit")
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
    vim.bo.filetype = "argocd"
  end)
end

function M.sync_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoSync <app-name>", vim.log.levels.WARN)
    return
  end
  run_cmd({"argocd", "app", "sync", app_name}, function(data)
    vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
  end)
end

function M.diff_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoDiff <app-name>", vim.log.levels.WARN)
    return
  end
  run_cmd({"argocd", "app", "diff", app_name}, function(data)
    vim.cmd("vsplit")
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
    vim.bo.filetype = "diff"
  end)
end

function M.logs_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoLogs <app-name>", vim.log.levels.WARN)
    return
  end
  run_cmd({"kubectl", "logs", "deployment/" .. app_name, "--tail=50"}, function(data)
    vim.cmd("vsplit")
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
    vim.bo.filetype = "log"
  end)
end

function M.delete_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoDelete <app-name>", vim.log.levels.WARN)
    return
  end
  vim.ui.select({"No", "Yes"}, {
    prompt = "Are you sure you want to delete " .. app_name .. "?",
  }, function(choice)
    if choice == "Yes" then
      run_cmd({"argocd", "app", "delete", app_name, "--yes"}, function(data)
        vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
      end)
    end
  end)
end

function M.rollback_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoRollback <app-name>", vim.log.levels.WARN)
    return
  end
  run_cmd({"argocd", "app", "history", app_name, "--output", "name"}, function(history)
    if not history or #history == 0 then
      vim.notify("No history found for " .. app_name, vim.log.levels.INFO)
      return
    end
    vim.ui.select(history, {
      prompt = "Select a revision to rollback to:",
    }, function(revision)
      if revision then
        run_cmd({"argocd", "app", "rollback", app_name, revision}, function(data)
          vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
        end)
      end
    end)
  end)
end

function M.telescope_apps()
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  run_cmd({"argocd", "app", "list", "--output", "name"}, function(data)
    pickers.new({}, {
      prompt_title = 'ArgoCD Apps',
      finder = finders.new_table {
        results = data,
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        map('i', '<C-s>', function()
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.sync_app(selection[1])
          end
        end)
        map('i', '<C-d>', function()
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.diff_app(selection[1])
          end
        end)
        map('i', '<C-l>', function()
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.logs_app(selection[1])
          end
        end)
        map('i', '<C-x>', function()
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.delete_app(selection[1])
          end
        end)
        map('i', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.rollback_app(selection[1])
          end
        end)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection[1] then
            M.sync_app(selection[1])
          end
        end)
        return true
      end
    }):find()
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("ArgoList", M.list_apps, {})
  vim.api.nvim_create_user_command("ArgoSync", function(opts)
    M.sync_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoDiff", function(opts)
    M.diff_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoLogs", function(opts)
    M.logs_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoDelete", function(opts)
    M.delete_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoRollback", function(opts)
    M.rollback_app(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("ArgoPick", M.telescope_apps, {})
end

return M
