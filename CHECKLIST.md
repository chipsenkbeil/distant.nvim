# Checklist

This represents a checklist to do before each stable release of the plugin.

### Version updates

Within `lua/distant/init.lua`, we need to ensure two fields are up-to-date:

1. `MIN_VERSION` represents the minimum CLI version to support (e.g.
   `0.20.0-alpha.7`)
2. `PLUGIN_VERSION` represents the version of the plugin and should match the
   tag we use minus the `v` prefix (e.g. `0.3.0`)

### Documentation updates

Re-generate vimdoc from our markdown. Ensure that it is reflected in
`doc/distant.txt` or other docs as well as [https://distant.dev/docs/neovim](https://distant.dev/docs/neovim).

### Changelog updates

Ensure that our changelog properly reflects the additions since the last
version. Additionally, these changes should be reflected at
[https://distant.dev/changelog/neovim](https://distant.dev/changelog/neovim).

### Tests pass

Like usual, all automated tests should pass on our CI. We can run these
manually using `make test-unit` and `make test-e2e` with the caveat that our
local machine needs to be configured for passwordless ssh in order to run the
end-to-end tests.

Additionally, beyond our automated tests, there are a series of manual tests we
should run to make sure the plugin works:

1. Try a full suite of `:DistantInstall` runs.
2. Open up the `:Distant` window 
