# ArgoCD Neovim Plugin

A lightweight Neovim plugin to control [ArgoCD](https://argoproj.github.io/) applications directly from your editor.  
Supports Lazy.nvim setup and integrates with [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for easy app selection and actions.

---

## Features

- Manage applications in a vertical split buffer
- Sync application
- Update application parameters
- Delete application
- Telescope picker with keybindings

## Requirements

- Neovim 0.7+ with Lua support  
- Telescope.nvim for picker support (optional)

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "lucaguindani/nvim-argocd",
  branch = "main",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim", -- optional
  },
}
```

## Usage

### Commands

| Command              | Description                                       |
|----------------------|---------------------------------------------------|
| `:ArgoList`          | Manage all apps (s=Sync, u=Update, d=Delete)      |
| `:ArgoSync <app>`    | Sync a specific app                               |
| `:ArgoUpdate <app>`  | Update a specific app                             |
| `:ArgoDelete <app>`  | Delete a specific app                             |
| `:ArgoPick`          | Telescope picker for app selection and actions    |
| `:ArgoLogout`        | Clear credentials                                 |

### Telescope keybindings

| Keys    | Action       |
|---------|--------------|
| `<CR>`  | Sync app     |
| `<C-s>` | Sync app     |
| `<C-u>` | Update app   |
| `<C-d>` | Delete app   |
