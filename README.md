# ArgoCD Neovim Plugin

A lightweight Neovim plugin to control [ArgoCD](https://argoproj.github.io/) applications directly from your editor.  
Supports Lazy.nvim setup and integrates with [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for easy app selection and actions.

---

## Features

- List applications in a vertical split buffer
- Sync applications
- Delete applications
- Telescope picker with keybindings for all major actions

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
    "nvim-telescope/telescope.nvim", -- optional but recommended
  },
}
```

## Usage

### Commands

| Command           | Description                            |
|-------------------|------------------------------------|
| `:ArgoList`       | List all apps                 |
| `:ArgoSync <app>` | Sync a specific app               |
| `:ArgoDelete <app>` | Delete a specific app |
| `:ArgoPick`       | Telescope picker for app selection and actions |
| `:ArgoLogout` | Clear credentials |


### Telescope picker keybindings

| Keys    | Action       |
|---------|--------------|
| `<CR>`  | Sync app     |
| `<C-s>` | Sync app     |
| `<C-d>` | Delete app   |

