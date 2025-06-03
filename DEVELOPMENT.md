# Plugin development guide

This document provides an overview of the plugin structure.

## Project Structure

```
lua/argocd/
├── init.lua        # Main module entry point, exports public functions
├── auth.lua        # ArgoCD authentication and credentials management
├── api.lua         # ArgoCD API client implementation
└── ui.lua          # UI-related functionalities

plugin/
└── argocd.lua     # Plugin entry point that creates user commands
```

## Module Responsibilities

### auth.lua
- Manages ArgoCD authentication state
- Handles credential storage and loading
- Provides login/logout functionality

### api.lua
- Implements the ArgoCD API client
- Handles HTTP requests to ArgoCD server
- Provides application management functions

### ui.lua
- Handles all UI-related functionalities

### init.lua
- Main module entry point
- Exports all public functions used by the plugin
- Initializes the module by loading credentials

### plugin/argocd.lua
- Plugin entry point loaded by Neovim
- Creates user commands (`:ArgoList`, `:ArgoSync`, etc.)
- Handles Neovim version checks
- Checks for required dependencies
