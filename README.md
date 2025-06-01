# ArgoCD Neovim Plugin

A lightweight Neovim plugin to control [ArgoCD](https://argoproj.github.io/argo-cd/) applications directly from your editor.  
Supports Lazy.nvim setup and integrates with [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for easy app selection and actions.

---

## Features

- List applications in a vertical split buffer
- Sync applications
- Delete applications with confirmation prompt
- Rollback applications to a selected revision
- Telescope picker with keybindings for all major actions

---

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "lucaguindani/nvim-argocd",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim", -- optional but recommended
  },
  cmd = {
    "ArgoList",
    "ArgoSync",
    "ArgoDelete",
    "ArgoRollback",
    "ArgoPick",
  },
  config = function()
    require("argocd").setup()
  end,
}
```

## Usage

### Commands

| Command           | Description                            |
|-------------------|------------------------------------|
| `:ArgoList`       | List all ArgoCD apps                 |
| `:ArgoSync <app>` | Sync the specified app               |
| `:ArgoDelete <app>` | Delete app with confirmation prompt |
| `:ArgoRollback <app>` | Rollback app to a selected revision |
| `:ArgoPick`       | Telescope picker for interactive app selection and actions |

### Telescope Picker Keybindings (insert mode)

| Keys    | Action       |
|---------|--------------|
| `<CR>`  | Sync app     |
| `<C-s>` | Sync app     |
| `<C-l>` | Show logs    |
| `<C-x>` | Delete app   |
| `<C-r>` | Rollback app |

---

### Requirements

- Neovim 0.7+ with Lua support  
- Telescope.nvim for picker support (optional)
