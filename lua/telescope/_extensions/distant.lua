local extension = require('telescope._extensions.distant.extension')

return require('telescope').register_extension {
    exports = extension.pickers,
}
