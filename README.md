# ArgoCD Neovim Plugin

A lightweight Neovim plugin to control [ArgoCD](https://argoproj.github.io/) applications directly from your editor.  
Supports Lazy.nvim setup and integrates with [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for easy app selection and actions.

---

## Features

- Manage multiple applications in an horizontal split buffer
- Sync an application
- Hard refresh an application
- Update an application parameters
- Delete an application
- Use Telescope picker with keybindings
- Use contexts to work with multiple ArgoCD instances simultaneously

## Requirements

- Neovim 0.7+
- Telescope.nvim (optional)

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "lucaguindani/nvim-argocd",
  branch = "main",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "rcarriga/nvim-notify",
    "nvim-telescope/telescope.nvim", -- optional
  },
}
```

## Authentication

The plugin uses the ArgoCD API for authentication. Your credentials are stored in a local file called `argocd-credentials.json`.

### Context management

The plugin supports managing multiple ArgoCD contexts, allowing you to work with different ArgoCD instances simultaneously.

First, add a context using the `:ArgoContextAdd <name> <host>` command, where `<name>` is a unique identifier for your context and `<host>` is the URL of your ArgoCD instance. If you haven't logged in yet with `:ArgoLogin`, you'll be prompted to do so. Upon successful login, you'll receive a token valid for 24 hours. When the token expires, the plugin will attempt to automatically renew it using the environment variables if they are set (see [Token auto-renewal](#token-auto-renewal) for details). If not, you'll be prompted to re-enter your credentials.

| Command                         | Description                               |
|---------------------------------|-------------------------------------------|
| `:ArgoContextList`              | List all available ArgoCD contexts        |
| `:ArgoContextAdd <name> <host>` | Add a new ArgoCD context with host URL    |
| `:ArgoContextSwitch <name>`     | Switch to a different ArgoCD context      |
| `:ArgoContextRemove <name>`     | Remove an ArgoCD context                  |
| `:ArgoLogin`                    | Login to the current context              |
| `:ArgoLogout`                   | Logout from the current context           |

### Token auto-renewal

To enable automatic token renewal for a context, set the following environment variables:

```bash
export ARGOCD_USERNAME_<CONTEXT_NAME>="your-username"
export ARGOCD_PASSWORD_<CONTEXT_NAME>="your-password"
```

For example, for a context named "stage":
```bash
export ARGOCD_USERNAME_STAGE="your-username"
export ARGOCD_PASSWORD_STAGE="your-password"
```

## Commands

| Command              | Description                                           |
|----------------------|-------------------------------------------------------|
| `:ArgoList`          | Manage apps (s=Sync, u=Update, d=Delete, r=Refresh)   |
| `:ArgoSync <app>`    | Sync a specific app                                   |
| `:ArgoRefresh <app>` | Hard refresh of a specific app state                  |
| `:ArgoUpdate <app>`  | Update a specific app parameters                      |
| `:ArgoDelete <app>`  | Delete a specific app                                 |
| `:ArgoPick`          | Telescope picker for app selection and actions        |

## Telescope keybindings

| Keys    | Action       |
|---------|--------------|
| `<CR>`  | Sync app     |
| `<C-s>` | Sync app     |
| `<C-f>` | Refresh app  |
| `<C-u>` | Update app   |
| `<C-d>` | Delete app   |

## Testing

The plugin includes basic tests for its core modules. Use the following command to run them from the project root directory.

```bash
make test
```

The tests are run using Neovim's built-in testing capabilities with the help of Plenary.nvim. They verify that the basic structure and function exposure of each module is correct without testing actual functionality or API interactions.
