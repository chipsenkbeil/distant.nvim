# distant.nvim

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

Supports the following features against remote machines:

- Retrieving a list of available files & directories
- Creating and deleting files & directories
- Copying files & directories
- Renaming files & directories
- Running [LSPs](https://neovim.io/doc/lsp/) remotely and getting live results locally
- Optional [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  integration

**Requires neovim 0.5+**

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- With no optional plugins
use 'chipsenkbeil/distant.nvim'

-- With telescope plugin
use {
  'chipsenkbeil/distant.nvim',
  requires = {
    {'nvim-lua/plenary.nvim'},
    {'nvim-lua/popup.nvim'},
    {'nvim-telescope/telescope.nvim'},
  },
  config = function()
    require('telescope').load_extension('distant')
  end,
}
```

## Getting Started

In order to operate against a remote machine, we first need to establish
a connection to it. To do this, we run `:DistantLaunch {host}` where the host
points to the remote machine and can be an IP address like `127.0.0.1` or
a domain like `example.com`.

The launch command will attempt to SSH into the remote machine using port 22
by default and start an instance of [`distant`](https://github.com/chipsenkbeil/distant).

Once started, all remote operations will be sent to that machine!

## Functions

| Functions   | Description                                                                           |
|-------------|---------------------------------------------------------------------------------------|
| `fn.copy`   | Copies a remote file or directory to another remote location                          |
| `fn.edit`   | Opens a remote file for editing                                                       |
| `fn.list`   | Lists remote files & directories in the current working directory of the server       |
| `fn.mkdir`  | Creates a new directory remotely                                                      |
| `fn.remove` | Removes a remote file or directory remotely                                           |
| `fn.run`    | Runs a remote program async                                                           |

| Functions         | Description                                   |
|-------------------|-----------------------------------------------|
| `fn.async.copy`   | Async variant of `fn.copy` using callbacks    |
| `fn.async.edit`   | Async variant of `fn.copy` using callbacks    |
| `fn.async.list`   | Async variant of `fn.list` using callbacks    |
| `fn.async.mkdir`  | Async variant of `fn.mkdir` using callbacks   |
| `fn.async.remove` | Async variant of `fn.remove` using callbacks  |
| `fn.async.run`    | Async variant of `fn.run` using callbacks     |

## Commands

| Commands              | Description                                       |
|-----------------------------|---------------------------------------------|
| `DistantClearSession` | Alias to `lua require('distant').session.clear`   |
| `DistantCopy`         | Alias to `lua require('distant').fn.copy`         |
| `DistantEdit`         | Alias to `lua require('distant').fn.edit`         |
| `DistantLaunch`       | Alias to `lua require('distant').launch`          |
| `DistantList`         | Alias to `lua require('distant').fn.list`         |
| `DistantMkdir`        | Alias to `lua require('distant').fn.mkdir`        |
| `DistantRemove`       | Alias to `lua require('distant').fn.remove`       |
| `DistantRun`          | Alias to `lua require('distant').fn.run`          |

## telescope Integration

TODO

## License

This project is licensed under either of

Apache License, Version 2.0, (LICENSE-APACHE or
[apache-license][apache-license]) MIT license (LICENSE-MIT or
[mit-license][mit-license]) at your option.

[apache-license]: http://www.apache.org/licenses/LICENSE-2.0
[mit-license]: http://opensource.org/licenses/MIT
