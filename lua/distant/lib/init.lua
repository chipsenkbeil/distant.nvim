-- TODO: Properly detect if this library is accessible. If not, we need to provide
--       two options:
--
--       1. Download a pre-built library using curl for the detected OS
--       2. Build from source by cloning the repository, running cargo build --release,
--          and copying the release artifact to the appropriate location
return require('distant_lua')
