# distant.nvim

[![CI](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml)

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

- **Requires neovim 0.8+**
- **Requires distant 0.20.x**

🚧 **(Alpha stage software) This plugin is in rapid development and may
break or change frequently!** 🚧

## Features

Supports the following features against remote machines:

- [X] Retrieving a list of available files & directories
- [X] Editing remote files
- [X] Creating and deleting files & directories
- [X] Copying files & directories
- [X] Renaming files & directories
- [X] Running [LSPs](https://neovim.io/doc/lsp/) remotely and getting live results locally
- [X] [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) integration via `:Telescope distant search`

## Installation & Setup

> It is **highly** recommended to not use the master branch of this plugin.
> Instead, prefer either a branch (`v0.3`) or a specific tag (`v0.3.0`) to lock
> in the plugin. When using a branch, you will get rolling updates to that
> branch. When using a tag, you are locked into the features and stability of
> the plugin at that point!

Using [packer.nvim](https://github.com/wbthomason/packer.nvim), the quickest
way to get up and running is the following:

```lua
use {
  'chipsenkbeil/distant.nvim',
  branch = 'v0.3',
  config = function()
    local distant = require('distant')
    distant:setup()
  end
}
```

#### Within a file

| Key | Action                         |
|-----|--------------------------------|
| `-` | `lua distant.nav.actions.up()` |

#### Within a directory

| Key        | Action                              |
|------------|-------------------------------------|
| `<Return>` | `lua distant.nav.actions.edit()`    |
| `-`        | `lua distant.nav.actions.up()`      |
| `K`        | `lua distant.nav.actions.mkdir()`   |
| `N`        | `lua distant.nav.actions.newfile()` |
| `R`        | `lua distant.nav.actions.rename()`  |
| `D`        | `lua distant.nav.actions.remove()`  |

#### Post-setup

Run `:DistantInstall` to complete the setup.

* For more information on installation, check out `:help distant-installation`
* For more information on settings, check out `:help distant-settings`

## Getting Started

In order to operate against a remote machine, we first need to establish
a connection to it. To do this, we run `:DistantLaunch {host}` where the host
points to the remote machine and can be an IP address like `127.0.0.1` or
a domain like `example.com`.

The launch command will attempt to SSH into the remote machine using port 22
by default and start an instance of [`distant`](https://github.com/chipsenkbeil/distant).

Once started, all remote operations will be sent to that machine! You can try
out something simple like displaying a list of files, directories, and symlinks
by running `:DistantOpen /some/dir`, which will open a dialog that displays
all of the contents of the specified directory.

## Documentation

For more details on available functions, settings, commands, and more,
please check out the [online help documentation](https://distant.dev/editors/neovim/).

## License

This project is licensed under either of

Apache License, Version 2.0, (LICENSE-APACHE or
[apache-license][apache-license]) MIT license (LICENSE-MIT or
[mit-license][mit-license]) at your option.

[apache-license]: http://www.apache.org/licenses/LICENSE-2.0
[mit-license]: http://opensource.org/licenses/MIT
