# Plugin development guide

This document provides an overview of the plugin structure.

## Project Structure

```
lua/argocd/
├── init.lua        # Main module entry point, UI-related functionalities
├── auth.lua        # ArgoCD authentication and credentials management
├── api.lua         # ArgoCD API client implementation
plugin/
└── argocd.lua      # Plugin entry point, creates user commands
```

## Module Responsibilities

### auth.lua
- Manages ArgoCD authentication state with multiple contexts
- Handles credential storage and loading per context
- Provides context management (add, switch, remove contexts)
- Provides login/logout functionality per context

### api.lua
- Implements the ArgoCD API client
- Handles HTTP requests to ArgoCD server
- Provides application management functions

### init.lua
- Main module entry point
- Exports all public functions used by the plugin
- Handles all UI-related functionalities

### plugin/argocd.lua
- Plugin entry point loaded by Neovim
- Creates user commands (`:ArgoList`, `:ArgoSync`, etc.)
- Checks for required dependencies
