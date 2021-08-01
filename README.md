# distant.nvim

A wrapper around [`distant`](https://github.com/chipsenkbeil/distant) that
enables users to edit remote files from the comfort of their local environment.

Supports the following features against remote machines:

- Retrieving a list of available files & directories
- Creating and deleting files & directories
- Copying files & directories
- Renaming files & directories
- Running [LSPs](https://neovim.io/doc/lsp/) remotely and getting live results locally
- Optional [lir.nvim](https://github.com/tamago324/lir.nvim integration) integration
- Optional [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) integration

**Requires neovim 0.5+**

## Installation

> Not ready for usage yet! Features are still being developed!

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- With no optional plugins
use 'chipsenkbeil/distant.nvim'

-- With lir plugin
use {
  'chipsenkbeil/distant.nvim',
  requires = {
    {'nvim-lua/plenary.nvim'},
    {'tamago324/lir.nvim'},
  },
  config = function()
    local actions = require('lir.distant.actions')
    require('lir.distant').setup {
      mappings = {
        ['l']     = actions.edit,
        ['<C-s>'] = actions.split,
        ['<C-v>'] = actions.vsplit,
        ['<C-t>'] = actions.tabedit,
      }
    }
  end,
}

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

Once started, all remote operations will be sent to that machine! You can try
out something simple like displaying a list of files, directories, and symlinks
by running `:DistantDirList /some/dir`, which will open a dialog that displays
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
| `fn.mkdir`            | Creates a new directory remotely                                              |
| `fn.read_file_text`   | Reads a remote file, returning its content as text                            |
| `fn.remove`           | Removes a remote file or directory                                            |
| `fn.rename`           | Renames a remote file or directory                                            |
| `fn.run`              | Runs a remote program to completion, returning stdout, stderr, and exit code  |
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
| `fn.async.mkdir`              | Async variant of `fn.mkdir` using callbacks               |
| `fn.async.read_file_text`     | Async variant of `fn.read_file_text` using callbacks      |
| `fn.async.remove`             | Async variant of `fn.remove` using callbacks              |
| `fn.async.rename`             | Async variant of `fn.rename` using callbacks              |
| `fn.async.run`                | Async variant of `fn.run` using callbacks                 |
| `fn.async.write_file_text`    | Async variant of `fn.write_file_text` using callbacks     |

## Commands

Alongside functions, this plugin also provides vim commands that can be used to
initiate different tasks remotely. It also includes specialized commands such
as `DistantLaunch` that is used to start a remote session.

| Commands              | Description                                            |
|-----------------------------|--------------------------------------------------|
| `DistantClearSession` | Alias to `lua require('distant').session.clear`        |
| `DistantCopy`         | Alias to `lua require('distant').fn.copy`              |
| `DistantLaunch`       | Alias to `lua require('distant').ui.launch`            |
| `DistantDirList`      | Alias to `lua require('distant').fn.dir_list`          |
| `DistantMkdir`        | Alias to `lua require('distant').fn.mkdir`             |
| `DistantRemove`       | Alias to `lua require('distant').fn.remove`            |
| `DistantRename`       | Alias to `lua require('distant').fn.rename`            |
| `DistantRun`          | Alias to `lua require('distant').fn.run`               |
| `DistantSessionInfo`  | Alias to `lua require('distant').ui.show_session_info` |

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
