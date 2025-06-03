local M = {}
local api = require("argocd.api")
local telescope = require("telescope.builtin")

-- Create floating window for application list
function M.create_app_list_window()
  local width = math.floor(vim.o.columns * 0.3)
  local height = math.floor(vim.o.lines * 0.3)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Set up buffer and window options for app list
  vim.api.nvim_buf_set_name(buf, "ArgoCD Apps")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "readonly", true)

  -- Set filetype
  vim.bo[buf].filetype = "argocd"

  return buf, win_id
end

-- Create floating window for parameter editing
function M.create_edit_window(width, height, app_name)
  local width = width or math.floor(vim.o.columns * 0.4)
  local height = height or math.floor(vim.o.lines * 0.4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Edit " .. app_name .. " parameters ",
    title_pos = "center",
    footer = {
      { " <CR> to save, q to quit ", "Comment" }
    },
    footer_pos = "center",
  })

  -- Set up buffer and window options for parameter editing
  vim.api.nvim_buf_set_name(buf, "ArgoCD Parameters")
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "readonly", false)

  -- Set filetype
  vim.bo[buf].filetype = "argocdparams"

  return buf, win_id
end

-- Update application in a floating window
function M.update_app(app_name)
  if not app_name or app_name == "" then
    vim.notify("Usage: :ArgoUpdate <app-name>", vim.log.levels.WARN)
    return
  end

  -- Get current parameters
  local params, err = api.get_app_parameters(app_name)
  if not params then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Prepare editable lines: key=value
  local param_lines = {}
  for _, p in ipairs(params) do
    table.insert(param_lines, (p.name or "") .. "=" .. (p.value or ""))
  end

  -- Create floating window for editing
  local edit_buf, win = M.create_edit_window(nil, nil, app_name)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, param_lines)

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

      -- Update parameters using API
      local success, msg = api.update_app_parameters(app_name, new_params)
      vim.notify(msg, success and vim.log.levels.INFO or vim.log.levels.ERROR)
      if success then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })

  -- Quit handler: q in normal mode
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  -- Set up buffer cleanup
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = edit_buf,
    callback = function()
      vim.api.nvim_buf_delete(edit_buf, { force = true })
    end,
  })
end

local app_list_timer = nil
local buf = nil
local win_id = nil
local app_names = {}

function M.list_apps()
  -- Create floating window for app list
  buf, win_id = M.create_app_list_window()

  -- Get applications using API
  app_names, err = api.get_applications()
  if not app_names then
    vim.notify(err, vim.log.levels.ERROR)
    return buf
  end

  -- Draw applications
  local function draw_lines()
    if not vim.api.nvim_buf_is_valid(buf) then return end

    local lines = {}
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

    for i, app in ipairs(app_names) do
      local base = string.format("%s %s", app.icon, app.name)
      if i == cursor_line then
        base = base .. string.format(" (%s %s)", app.branch, app.sha)
      end
      lines[i] = base
    end

    -- Allow temporary buffer modification
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

    -- Add highlights
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

  -- Draw initial lines
  vim.schedule(draw_lines)

  -- Set up autocommand for cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      vim.schedule(draw_lines)
    end,
    desc = "Highlight branch and SHA on current line",
  })

  -- Set up auto-update timer
  if app_list_timer then
    app_list_timer:stop()
    app_list_timer:close()
  end

  app_list_timer = vim.loop.new_timer()
  app_list_timer:start(
    0, -- Start immediately
    5000, -- Repeat every 5 seconds
    vim.schedule_wrap(function()
      if vim.api.nvim_win_is_valid(win_id) then
        M.list_apps()
      else
        app_list_timer:stop()
        app_list_timer:close()
        app_list_timer = nil
      end
    end)
  )

  -- Set keymaps
  vim.api.nvim_buf_set_keymap(buf, "n", "u", "", {
    noremap = true,
    silent = true,
    callback = function()
      local line_nr = vim.api.nvim_win_get_cursor(0)[1]
      if line_nr > 0 and line_nr <= #app_names then
        require("argocd").update_app(app_names[line_nr].name)
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "s", "", {
    noremap = true,
    silent = true,
    callback = function()
      local line_nr = vim.api.nvim_win_get_cursor(0)[1]
      local app = app_names[line_nr]
      if app then
        require("argocd").sync_app(app.name)
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "d", "", {
    noremap = true,
    silent = true,
    callback = function()
      local line_nr = vim.api.nvim_win_get_cursor(0)[1]
      local app = app_names[line_nr]
      if app then
        require("argocd").delete_app(app.name)
      end
    end,
  })

  -- Disable orange highlight on line number
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("highlight CursorLineNr NONE")
  end)

  return buf
end

function M.telescope_apps()
  local buf = M.list_apps()
  if not vim.api.nvim_buf_is_valid(buf) then
    vim.notify("Failed to create apps buffer", vim.log.levels.ERROR)
    return
  end

  -- Get the current list of apps
  local apps = {}
  for _, app in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local name = app:match("%s+(.-)%s*")
    if name then
      table.insert(apps, name)
    end
  end

  telescope.find_files({
    prompt_title = "Select Application",
    results_title = "ArgoCD Applications",
    cwd = vim.api.nvim_buf_get_name(buf),
    attach_mappings = function(prompt_bufnr, map)
      -- Delete (d)
      map("i", "<C-d>", function()
        local selection = require("telescope.actions").get_selected_entry()
        if selection then
          local app_name = apps[selection.ordinal]
          if app_name then
            require("argocd").delete_app(app_name)
          end
        end
      end)

      -- Update (u)
      map("i", "<C-u>", function()
        local selection = require("telescope.actions").get_selected_entry()
        if selection then
          local app_name = apps[selection.ordinal]
          if app_name then
            require("argocd").update_app(app_name)
          end
        end
      end)

      -- Sync (s)
      map("i", "<C-s>", function()
        local selection = require("telescope.actions").get_selected_entry()
        if selection then
          local app_name = apps[selection.ordinal]
          if app_name then
            require("argocd").sync_app(app_name)
          end
        end
      end)

      return true
    end,
  })
end

return M
