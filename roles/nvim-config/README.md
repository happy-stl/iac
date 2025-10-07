# Neovim Configuration Ansible Role

This Ansible role sets up Neovim with optional lazy.nvim plugin manager support.

## Features

- Installs Neovim and required dependencies
- Configures basic Neovim settings
- Optional lazy.nvim plugin manager integration with official bootstrap
- Auto-reloading buffers when files change on disk
- Modern Lua-based configuration when using lazy.nvim
- Structured plugin configuration following lazy.nvim best practices
- Proper error handling for lazy.nvim installation

## Variables

### Required Variables

None - all variables have sensible defaults.

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `use_lazy_nvim` | `true` | Enable lazy.nvim plugin manager |
| `lazy_nvim_repo` | `"https://github.com/folke/lazy.nvim.git"` | Lazy.nvim repository URL |
| `lazy_nvim_path` | `"{{ nvim_config_dir }}/lazy/lazy.nvim"` | Path to lazy.nvim installation |
| `use_comment_nvim` | `false` | Enable Comment.nvim plugin |
| `nvim_config_dir` | `"{{ ansible_user_dir }}/.config/nvim"` | Neovim configuration directory |
| `nvim_config_file` | `"{{ nvim_config_dir }}/init.lua"` | Main configuration file |
| `packages` | `["neovim", "git"]` | Packages to install |

## Usage

### Basic Usage (with lazy.nvim)

```yaml
- hosts: localhost
  roles:
    - nvim-config
```

### Without lazy.nvim (legacy vim config)

```yaml
- hosts: localhost
  roles:
    - nvim-config
  vars:
    use_lazy_nvim: false
```

### Custom Configuration

```yaml
- hosts: localhost
  roles:
    - nvim-config
  vars:
    nvim_config_dir: "/home/user/.config/nvim"
    use_lazy_nvim: true
    use_comment_nvim: true
```

### With Comment Plugin

```yaml
- hosts: localhost
  roles:
    - nvim-config
  vars:
    use_lazy_nvim: true
    use_comment_nvim: true
```

## Configuration Files

- **With lazy.nvim**: 
  - Creates `init.lua` with official lazy.nvim bootstrap and all settings
  - Creates `lua/plugins/init.lua` for plugin configurations
  - Follows lazy.nvim best practices and official structure
- **Without lazy.nvim**: Creates `init.lua` with basic Neovim settings (no lazy.nvim)

**Note**: The role now uses only `init.lua` to avoid configuration conflicts. All settings from the previous `init.vim` have been merged into the Lua configuration.

## Adding Plugins

When using lazy.nvim, add your plugins to the `lua/plugins/init.lua` file. The template includes commented examples of common plugin configurations.

Example plugin configuration in `lua/plugins/init.lua`:
```lua
return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  
  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup()
    end,
  },
}
```

The configuration follows the official lazy.nvim documentation and includes proper error handling for the bootstrap process.

## Requirements

- Ansible 2.9+
- Linux system
- Git (for lazy.nvim installation)

## Dependencies

- `common` role (as specified in meta/main.yml)