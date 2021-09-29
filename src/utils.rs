use mlua::prelude::*;
use once_cell::sync::OnceCell;
use oorandom::Rand32;
use std::{
    sync::Mutex,
    time::{SystemTime, SystemTimeError, UNIX_EPOCH},
};

/// Return a random u32
pub fn rand_u32() -> LuaResult<u32> {
    static RAND: OnceCell<Mutex<Rand32>> = OnceCell::new();

    Ok(RAND
        .get_or_try_init::<_, SystemTimeError>(|| {
            Ok(Mutex::new(Rand32::new(
                SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
            )))
        })
        .to_lua_err()?
        .lock()
        .map_err(|x| x.to_string())
        .to_lua_err()?
        .rand_u32())
}
