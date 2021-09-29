use mlua::prelude::*;

mod runtime;
mod session;
mod utils;

pub use session::{LaunchOpts, Session};

#[mlua::lua_module]
fn distant_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    // get_session_by_id(id: usize) -> Session
    exports.set(
        "get_session_by_id",
        lua.create_function(|_, id: usize| Ok(Session::new(id)))?,
    )?;

    // launch(opts: LaunchOpts) -> Session
    exports.set(
        "launch",
        lua.create_async_function(|lua, value: LuaValue| async move {
            let opts = LaunchOpts::from_lua(value, lua)?;
            Session::launch(opts).await
        })?,
    )?;

    Ok(exports)
}
