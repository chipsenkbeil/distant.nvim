use distant_core::{Session, SessionExt};
use mlua::chunk;
use mlua::prelude::*;

#[mlua::lua_module]
fn distant_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set("hello", lua.create_function(hello)?)?;
    Ok(exports)
}

fn hello(lua: &Lua, name: String) -> LuaResult<LuaTable> {
    let t = lua.create_table()?;
    t.set("name", name.clone())?;
    let _globals = lua.globals();
    lua.load(chunk! {
        print("hello, " .. $name)
    })
    .exec()?;
    Ok(t)
}
