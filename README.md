# distant.nvim

[![CI](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml)

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

- **Requires neovim 0.8+**
- **Requires distant 0.20.x**

Visit https://distant.dev/editors/neovim/ for full documentation!

🚧 **(Alpha stage software) This plugin is in rapid development and may
break or change frequently!** 🚧

## Installation

### lazy.nvim

```lua
{
    'chipsenkbeil/distant.nvim', 
    branch = 'v0.3',
    config = function()
        require('distant'):setup()
    end
}
```

### packer.nvim

```lua
use {
    'chipsenkbeil/distant.nvim',
    branch = 'v0.3',
    config = function()
        require('distant'):setup()
    end
}
```

### vim-plug

```vim
Plug 'chipsenkbeil/distant.nvim', {
\ 'branch': 'v0.3',
\ 'do': ':lua require("distant"):setup()'
\ }
```

## Post-installation

> If you already have `distant` installed with a version that is compatible
> with the plugin, this step can be skipped. You can verify if `distant` is
> installed correctly by running `:checkhealth distant`.

Execute `:DistantInstall`.

A prompt will be provided where you can download a pre-built binary for your
local machine that will be placed in `~/.local/share/nvim/distant/` on Unix
systems or `~\AppData\Local\nvim-data\distant\` on Windows.

You can verify that it is available by running `:DistantClientVersion`.

See the [neovim installation
guide](http://distant.dev/editors/neovim/installation) for more information.

## Installing on your server

> If you want to just use distant to connect to an ssh server, you can skip
> this and the remaining steps and use `:DistantConnect ssh://example.com`.

Log into your remote machine and run this command to download a script to run
to install distant. In this example, we'll use ssh to install distant on a
Unix-compatible server (example.com):

```
ssh example.com 'curl -L https://sh.distant.dev | sh -s -- --on-conflict overwrite'
```

See the [distant CLI installation
guide](http://distant.dev/getting-started/installation) for more information.

## License

This project is licensed under either of

Apache License, Version 2.0, (LICENSE-APACHE or
[apache-license][apache-license]) MIT license (LICENSE-MIT or
[mit-license][mit-license]) at your option.

[apache-license]: http://www.apache.org/licenses/LICENSE-2.0
[mit-license]: http://opensource.org/licenses/MIT
