local distant = require('telescope._extensions.distant.search')

return require('telescope').register_extension {
    exports = distant.pickers,
}
