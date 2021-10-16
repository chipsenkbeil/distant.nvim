# distant.nvim

[![CI](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/chipsenkbeil/distant.nvim/actions/workflows/ci.yml)

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

- **Requires neovim 0.5+**
- **Requires distant 0.15.0+**

🚧 **(Alpha stage software) This plugin is in rapid development and may
break or change frequently!** 🚧

## Demo

[![Demo Video](https://img.youtube.com/vi/BuW2b1Ii0RI/0.jpg)](https://www.youtube.com/watch?v=BuW2b1Ii0RI)

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim), the quickest
way to get up and running is the following:

```lua
use {
  'chipsenkbeil/distant.nvim',
  config = function()
    require('distant').setup {
      -- Applies Chip's personal settings to every machine you connect to
      --
      -- 1. Ensures that distant servers terminate with no connections
      -- 2. Provides navigation bindings for remote directories
      -- 3. Provides keybinding to jump into a remote file's parent directory
      ['*'] = require('distant.settings').chip_default()
    }
  end
}
```

Normally, you would want to specify your own settings, both across all hosts
and custom settings for specific remote machines:

```lua
use {
  'chipsenkbeil/distant.nvim',
  config = function()
    local actions = require('distant.nav.actions')

    require('distant').setup {
      -- Apply these settings to the specific host
      ['example.com'] = {
        -- Specify a specific location for the distant binary on the remote machine
        distant = {
          bin = '/path/to/distant',
        }

        -- Specify an LSP to run for a specific project
        lsp = {
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
      --
      -- NOTE: These mirror what is returned with
      -- require('distant.settings').chip_default()
      ['*'] = {
        -- Apply these launch settings to all hosts
        distant = {
          -- Shutdown server after 60 seconds with no active connection
          args = {'--shutdown-after', '60'},
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
blocking fashion. Each function takes a single argument, which is a table
containing the arguments relevant for the function. Each function returns
two values: `err` being a userdata error or false, and `result` being the
results of the function call if it has any (like file text).

```lua
local fn = require('distant.fn')

local err, text = fn.read_file_text({path = 'path/to/file'})
if err then
  vim.api.nvim_err_writeln(tostring(err))
  return
end

print('Read file contents', text)
```

| Functions             | Description                                                                           |
|-----------------------|---------------------------------------------------------------------------------------|
| `fn.append_file`      | Appends binary data to a remote file                                                  |
| `fn.append_file_text` | Appends text to a remote file                                                         |
| `fn.copy`             | Copies a remote file or directory to another remote location                          |
| `fn.create_dir`       | Creates a new directory remotely                                                      |
| `fn.exists`           | Determines whether or not the path exists on the remote machine                       |
| `fn.metadata`         | Retrieves metadata about a remote file, directory, or symlink                         |
| `fn.read_dir`         | Lists remote files & directories for the given path on the remote machine             |
| `fn.read_file`        | Reads a remote file, returning its content as a list of bytes                         |
| `fn.read_file_text`   | Reads a remote file, returning its content as text                                    |
| `fn.remove`           | Removes a remote file or directory                                                    |
| `fn.rename`           | Renames a remote file or directory                                                    |
| `fn.spawn`            | Starts a process, returning it to support writing stdin and reading stdout and stderr |
| `fn.spawn_wait`       | Runs a remote program to completion, returning table of stdout, stderr, and exit code |
| `fn.system_info`      | Retrieves information about the remote machine such as its os name and arch           |
| `fn.write_file`       | Writes binary data to a remote file                                                   |
| `fn.write_file_text`  | Writes text to a remote file                                                          |

### Async Functions

Every blocking function above can also be called in a non-blocking fashion.
This is done by supplying a callback function as the last argument.

```lua
local fn = require('distant.fn')

fn.read_file_text({path = 'path/to/file'}, function(err, text)
  if err then
    vim.api.nvim_err_writeln(tostring(err))
    return
  end

  print('Read file contents', text)
end)
```

## Commands

Alongside functions, this plugin also provides vim commands that can be used to
initiate different tasks remotely. It also includes specialized commands such
as `DistantLaunch` that is used to start a remote session.

Commands support positional and key=value pairs. Positional arguments are
relative to each other and are not influenced by key=value pairs inbetween.

```
:DistantLaunch example.com distant.use_login_shell=true distant.args="--log-file /path/to/file.log --log-level info"
```

### Specialized Commands

These commands are geared towards performing actions that expose some dialogs
or other user interfaces within neovim.

| Commands              | Description                                               |
|-----------------------|-----------------------------------------------------------|
| `DistantOpen`         | Opens a file for editing or a directory for navigation    |
| `DistantLaunch`       | Opens a dialog to launch `distant` on a remote machine    |
| `DistantInstall`      | Triggers installation process for the C library           |
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
| `DistantRun`          | Alias to `lua require('distant').fn.spawn_wait`   |

## telescope Integration

TODO

## License

This project is licensed under either of

Apache License, Version 2.0, (LICENSE-APACHE or
[apache-license][apache-license]) MIT license (LICENSE-MIT or
[mit-license][mit-license]) at your option.

[apache-license]: http://www.apache.org/licenses/LICENSE-2.0
[mit-license]: http://opensource.org/licenses/MIT
