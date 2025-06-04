-- lua/argocd.lua

local M = {}
local Auth = require("argocd.auth")
local Api = require("argocd.api")

local app_list_timer = nil
local buf = nil -- Buffer for the app list
local app_names = {} -- Stores app data for the list

function M.list_apps()
  Auth.lazy_login(function()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end

    local function fetch_and_draw()
      if not vim.api.nvim_buf_is_valid(buf) then
        if app_list_timer then
          app_list_timer:stop()
          app_list_timer:close()
          app_list_timer = nil
        end
        return
      end

      local res = Api.get_applications()
      if res.status ~= 200 then
        vim.schedule(function()
          vim.notify("Failed to fetch apps: " .. res.body, vim.log.levels.ERROR)
        end)
        return
      end

      local json = vim.fn.json_decode(res.body)
      app_names = {}

      for i, app in ipairs(json.items or {}) do
        local sync_status = app.status.sync.status or "Unknown"
        local icon = (sync_status == "Synced") and "✓" or "⚠"
        local commit_sha = app.status.sync.revision or "unknown"
        local short_sha = commit_sha:sub(1, 7)
        local branch = app.spec.source.targetRevision or "unknown"

        app_names[i] = {
          name = app.metadata.name,
          icon = icon,
          sha = short_sha,
          branch = branch,
          status = sync_status,
        }
      end

      local function draw_lines()
        if not vim.api.nvim_buf_is_valid(buf) then
          -- Buffer was closed, stop timer and abort drawing
          if app_list_timer then
            app_list_timer:stop()
            app_list_timer:close()
            app_list_timer = nil
          end
          return
        end

        local lines = {}
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

        for i, app in ipairs(app_names) do
          -- Get status icon and highlight group
          local status_icon, status_hl
          if app.status == "Synced" then
            status_icon = status_icon or "✓"
            status_hl = status_hl or "String"
          else
            status_icon = status_icon or "⚠"
            status_hl = status_hl or "WarningMsg"
          end

          -- Build line: status icon + space + app name [+ branch and sha if current line]
          local base = string.format("%s %s", status_icon, app.name)

          if i == cursor_line then
            base = base .. string.format(" (%s %s)", app.branch, app.sha)
          end

          lines[i] = base
        end

        -- Allow temporary buffer modification
        vim.bo[buf].modifiable = true
        -- List projects
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        -- Disable buffer modification
        vim.bo[buf].modifiable = false
        vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

        for i, app in ipairs(app_names) do
          -- Highlight status icon (1 char usually)
          vim.api.nvim_buf_add_highlight(buf, -1, (app.status == "Synced") and "String" or "WarningMsg", i - 1, 0, 1)

          -- Highlight app name (starts at col 2)
          local name_start = 2
          vim.api.nvim_buf_add_highlight(buf, -1, "Normal", i - 1, name_start, name_start + #app.name)

          -- Highlight branch and sha on current line as comment
          if i == cursor_line then
            local comment_pos = lines[i]:find("%(")
            if comment_pos then
              vim.api.nvim_buf_add_highlight(buf, -1, "Comment", i - 1, comment_pos - 1, -1)
            end
          end
        end
      end

      vim.schedule(draw_lines)

      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = buf,
        callback = function()
          vim.schedule(draw_lines)
        end,
        desc = "Highlight branch and SHA on current line",
      })
    end

    vim.cmd("vsplit")
    local total_cols = vim.o.columns
    local quarter = math.floor(total_cols / 3)
    vim.cmd("vertical resize " .. quarter)
    vim.cmd("enew")
    buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = "argocd"
    -- Make buffer non-modifiable to prevent insert mode
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = false

    -- Disable orange highlight on line number for this buffer
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("highlight CursorLineNr NONE")
    end)

    -- Set key to sync the project under cursor
    vim.api.nvim_buf_set_keymap(buf, "n", "s", "", {
      noremap = true,
      silent = true,
      callback = function()
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local app = app_names[line_nr]
        if not app then return end
        M.sync_app(app.name)
      end,
    })

    -- Set key to delete the project under cursor
    vim.api.nvim_buf_set_keymap(buf, "n", "d", "", {
      noremap = true,
      silent = true,
      callback = function()
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local app = app_names[line_nr]
        if not app then return end
        M.delete_app(app.name)
      end,
    })

    -- Set key to update the project under cursor
    vim.api.nvim_buf_set_keymap(buf, "n", "u", "", {
      noremap = true,
      silent = true,
      callback = function()
        local line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local app = app_names[line_nr]
        if not app then return end
        M.update_app(app.name)
      end,
    })

    fetch_and_draw()

    -- Start the timer and save the handle
    app_list_timer = vim.loop.new_timer()
    app_list_timer:start(0, 5000, vim.schedule_wrap(fetch_and_draw))

    -- Stop timer when buffer is unloaded
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload", "WinClosed" }, {
      buffer = buf,
      once = true,
      callback = function()
        if app_list_timer then
          app_list_timer:stop()
          app_list_timer:close()
          app_list_timer = nil
        end
      end,
    })
  end)
end

function M.update_app(app_name)
  Auth.lazy_login(function()
    if not app_name or app_name == "" then
      vim.notify("Usage: :ArgoUpdate <app-name>", vim.log.levels.WARN)
      return
    end

    -- Fetch full app data
    local res = Api.get_application_details(app_name)
    if res.status ~= 200 then
      vim.notify("Failed to fetch app: " .. res.body, vim.log.levels.ERROR)
      return
    end
    local app_data = vim.fn.json_decode(res.body)
    local params = {}
    if app_data.spec and app_data.spec.source and app_data.spec.source.helm and app_data.spec.source.helm.parameters then
      params = app_data.spec.source.helm.parameters
    end

    -- Prepare editable lines: key=value
    local param_lines = {}
    for _, p in ipairs(params) do
      table.insert(param_lines, (p.name or "") .. "=" .. (p.value or ""))
    end

    -- Floating window for editing
    local edit_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, param_lines)
    vim.bo[edit_buf].filetype = "argocdparams"
    vim.bo[edit_buf].buftype = "acwrite"
    vim.bo[edit_buf].bufhidden = "wipe"
    vim.bo[edit_buf].modifiable = true

    local title = " Edit " .. app_name .. " parameters "
    local width = math.max(50, #title + 4)
    local height = math.max(7, #param_lines + 2)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    local win = vim.api.nvim_open_win(edit_buf, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      title = title,
      title_pos = "center",
      footer = {
        { " <CR> to save, q to quit ", "Comment" }
      },
      footer_pos = "center",
    })

    -- Save handler: <CR> in normal mode
    vim.api.nvim_buf_set_keymap(edit_buf, "n", "<CR>", "", {
      noremap = true,
      silent = true,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        local new_params = {}
        for _, line in ipairs(lines) do
          local k, v = line:match("^([^=]+)=(.*)$")
          if k then
            table.insert(new_params, { name = k, value = v })
          end
        end
        local patch_body = {
          name = app_name,
          patch = vim.fn.json_encode({
            spec = {
              source = {
                helm = {
                  parameters = new_params
                }
              }
            }
          }),
          patchType = "merge"
        }
        local patch_res = Api.update_application_params(app_name, patch_body)
        if patch_res.status == 200 then
          vim.notify("Parameters updated for " .. app_name, vim.log.levels.INFO)
          vim.api.nvim_win_close(win, true)
        else
          vim.notify("Update failed: " .. patch_res.body, vim.log.levels.ERROR)
        end
      end,
    })

    -- Quit handler: q
    vim.api.nvim_buf_set_keymap(edit_buf, "n", "q", "", {
      noremap = true,
      silent = true,
      callback = function()
        vim.api.nvim_win_close(win, true)
      end,
    })

    -- Move cursor to first line
    vim.api.nvim_win_set_cursor(win, {1, 0})
  end)
end

function M.sync_app(app_name)
  Auth.lazy_login(function()
    if not app_name or app_name == "" then
      vim.notify("Usage: :ArgoSync <app-name>", vim.log.levels.WARN)
      return
    end
    local res = Api.get_application_details(app_name)
    if res.status ~= 200 then
      vim.notify("Failed to fetch app status: " .. res.body, vim.log.levels.ERROR)
      return
    end
    local app_data = vim.fn.json_decode(res.body)
    local app_status = app_data.status.sync.status or "Unknown"
    if app_status ~= "Synced" then 
      vim.ui.select({"No", "Yes"}, {
        prompt = "Are you sure you want to sync " .. app_name .. "?",
      }, function(choice)
        if choice == "Yes" then
          local res = Api.sync_application(app_name)
          if res.status == 200 then
            vim.notify("Sync triggered for " .. app_name, vim.log.levels.INFO)
          else
            vim.notify("Sync failed: " .. res.body, vim.log.levels.ERROR)
          end
        else
          vim.notify("Sync cancelled", vim.log.levels.INFO)
        end
      end)
    else
      vim.notify(app_name .. " is already synced.", vim.log.levels.INFO)
    end
  end)
end

function M.delete_app(app_name)
  Auth.lazy_login(function()
    if not app_name or app_name == "" then
      vim.notify("Usage: :ArgoDelete <app-name>", vim.log.levels.WARN)
      return
    end
    vim.ui.select({"No", "Yes"}, {
      prompt = "Are you sure you want to delete " .. app_name .. "?",
    }, function(choice)
      if choice == "Yes" then
        local res = Api.delete_application(app_name)
        if res.status == 200 then
          vim.notify("Deleted " .. app_name, vim.log.levels.INFO)
        else
          vim.notify("Delete failed: " .. res.body, vim.log.levels.ERROR)
        end
      else
        vim.notify("Delete cancelled", vim.log.levels.INFO)
      end
    end)
  end)
end

function M.clear_credentials()
  Auth.clear_credentials()
end

function M.telescope_apps()
  local has_telescope = pcall(require, "telescope")

  if not has_telescope then
    vim.notify("[nvim-argocd] telescope.nvim is not installed!", vim.log.levels.WARN)
    return nil
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local res = Api.get_applications()
  if res.status ~= 200 then
    vim.notify("Failed to fetch apps: " .. res.body, vim.log.levels.ERROR)
    return
  end

  local json = vim.fn.json_decode(res.body)
  local apps = {}
  for _, app in ipairs(json.items or {}) do
    table.insert(apps, app.metadata.name)
  end

  pickers.new({}, {
    prompt_title = 'ArgoCD Apps',
    finder = finders.new_table {
      results = apps,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<C-s>', function()
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.sync_app(selection[1])
        end
      end)
      map('i', '<C-u>', function()
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.update_app(selection[1])
        end
      end)
      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          M.delete_app(selection[1])
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
end

return M
