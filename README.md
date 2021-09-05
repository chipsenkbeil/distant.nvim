# distant.nvim

[![CI](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml)

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

- **Requires neovim 0.5+**
- **Requires distant 0.13.0+**

🚧 **(Alpha stage software) This plugin is in rapid development and may
break or change frequently!** 🚧

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'chipsenkbeil/distant.nvim',
  config = function()
    local actions = require('distant.nav.actions')

    require('distant').setup {
      -- Apply these settings to the specific host
      ['example.com'] = {
        launch = {
          -- Specify a specific location for the distant binary on the remote machine
          distant = '/path/to/distant',
        }

        lsp = {
          -- Specify an LSP to run for a specific project
          ['My Project'] = {
            cmd = '/path/to/rust-analyzer',
            root_dir = '/path/to/project/root',

            -- Do your on_attach with keybindings like you would with
            -- nvim-lspconfig
            on_attach = function() 
              -- Apply some general bindings for every buffer supporting lsp
            end,
          },
        },
      },

      -- Apply these settings to any remote host
      ['*'] = {
        -- Apply these launch settings to all hosts
        launch = {
          -- Apply additional CLI options to the listening server, such as
          -- shutting down when there is no connection to it after 30 seconds
          extra_server_args = '"--shutdown-after 30"',
        },

        -- Specify mappings to apply on remote file buffers
        -- Presently, the only one you would want is some way to trigger
        -- file navigation
        file = {
          mappings = {
            ['-']         = actions.up,
          },
        },

        -- Specify mappings to apply on remote directory bufffers
        dir = {
          mappings = {
            ['<Return>']  = actions.edit,
            ['-']         = actions.up,
            ['K']         = actions.mkdir,
            ['N']         = actions.newfile,
            ['R']         = actions.rename,
            ['D']         = actions.remove,
          }
        },
      }
    }
  end
}
```

## Features

Supports the following features against remote machines:

- [X] Retrieving a list of available files & directories
- [X] Editing remote files
- [X] Creating and deleting files & directories
- [X] Copying files & directories
- [X] Renaming files & directories
- [X] Running [LSPs](https://neovim.io/doc/lsp/) remotely and getting live results locally

Support is coming up for these features:

- [ ] Optional [lir.nvim](https://github.com/tamago324/lir.nvim) integration
- [ ] Optional [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) integration

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

## Functions

### Blocking Functions

Synchronous functions are available that perform the given operation in a
blocking fashion. All blocking functions support being provided a timeout and
interval to check said timeout, defaulting both to the global settings. For
more details, check out the doc comments for the individual functions.

| Functions             | Description                                                                   |
|-----------------------|-------------------------------------------------------------------------------|
| `fn.copy`             | Copies a remote file or directory to another remote location                  |
| `fn.dir_list`         | Lists remote files & directories for the given path on the remote machine     |
| `fn.metadata`         | Retrieves metadata about a remote file, directory, or symlink                 |
| `fn.mkdir`            | Creates a new directory remotely                                              |
| `fn.read_file_text`   | Reads a remote file, returning its content as text                            |
| `fn.remove`           | Removes a remote file or directory                                            |
| `fn.rename`           | Renames a remote file or directory                                            |
| `fn.run`              | Runs a remote program to completion, returning stdout, stderr, and exit code  |
| `fn.system_info`      | Retrieves information about the remote machine such as its os name and arch   |
| `fn.write_file_text`  | Writes text to a remote file                                                  |

### Async Functions

Asynchronous functions are available that use callbacks when functions are
executed. The singular argument to the callback matches that of the return
value of the synchronous function. For more details, check out the doc comments
for the individual functions.

| Functions                     | Description                                               |
|-------------------------------|-----------------------------------------------------------|
| `fn.async.copy`               | Async variant of `fn.copy` using callbacks                |
| `fn.async.dir_list`           | Async variant of `fn.dir_list` using callbacks            |
| `fn.async.metadata`           | Async variant of `fn.metadata` using callbacks            |
| `fn.async.mkdir`              | Async variant of `fn.mkdir` using callbacks               |
| `fn.async.read_file_text`     | Async variant of `fn.read_file_text` using callbacks      |
| `fn.async.remove`             | Async variant of `fn.remove` using callbacks              |
| `fn.async.rename`             | Async variant of `fn.rename` using callbacks              |
| `fn.async.run`                | Async variant of `fn.run` using callbacks                 |
| `fn.async.system_info`        | Async variant of `fn.system_info` using callbacks         |
| `fn.async.write_file_text`    | Async variant of `fn.write_file_text` using callbacks     |

## Commands

Alongside functions, this plugin also provides vim commands that can be used to
initiate different tasks remotely. It also includes specialized commands such
as `DistantLaunch` that is used to start a remote session.

### Specialized Commands

These commands are geared towards performing actions that expose some dialogs
or other user interfaces within neovim.

| Commands              | Description                                               |
|-----------------------|-----------------------------------------------------------|
| `DistantOpen`         | Opens a file for editing or a directory for navigation    |
| `DistantLaunch`       | Opens a dialog to launch `distant` on a remote machine    |
| `DistantMetadata`     | Presents information about some path on a remote machine  |
| `DistantSessionInfo`  | Presents information related to the remote connection     |
| `DistantSystemInfo`   | Presents information about remote machine itself          |

### Function Commands

These commands are purely wrappers around existing functions that accept those
function's arguments as input.

| Commands              | Description                                       |
|-----------------------|---------------------------------------------------|
| `DistantCopy`         | Alias to `lua require('distant').fn.copy`         |
| `DistantMkdir`        | Alias to `lua require('distant').fn.mkdir`        |
| `DistantRemove`       | Alias to `lua require('distant').fn.remove`       |
| `DistantRename`       | Alias to `lua require('distant').fn.rename`       |
| `DistantRun`          | Alias to `lua require('distant').fn.run`          |

## lir Integration

TODO

## telescope Integration

TODO

## License

This project is licensed under either of

Apache License, Version 2.0, (LICENSE-APACHE or
[apache-license][apache-license]) MIT license (LICENSE-MIT or
[mit-license][mit-license]) at your option.

[apache-license]: http://www.apache.org/licenses/LICENSE-2.0
[mit-license]: http://opensource.org/licenses/MIT
