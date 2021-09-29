use distant_ssh2::{Ssh2AuthHandler, Ssh2SessionOpts};
use mlua::prelude::*;
use serde::Deserialize;
use std::{fmt, io, time::Duration};

#[derive(Default)]
pub struct LaunchOpts<'a> {
    pub host: String,
    pub method: Method,
    pub handler: Ssh2AuthHandler<'a>,
    pub ssh: Ssh2SessionOpts,
    pub timeout: Duration,
}

impl fmt::Debug for LaunchOpts<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LaunchOpts")
            .field("host", &self.host)
            .field("method", &self.method)
            .field("handler", &"...")
            .field("ssh", &self.ssh)
            .field("timeout", &self.timeout)
            .finish()
    }
}

impl<'lua> FromLua<'lua> for LaunchOpts<'lua> {
    fn from_lua(lua_value: LuaValue<'lua>, lua: &'lua Lua) -> LuaResult<Self> {
        match lua_value {
            LuaValue::Table(tbl) => Ok(Self {
                host: tbl.get("host")?,
                method: lua.from_value(tbl.get("method")?)?,
                handler: Ssh2AuthHandler {
                    on_authenticate: {
                        let f: LuaFunction = tbl.get("on_authenticate")?;
                        Box::new(move |ev| {
                            let value = lua
                                .to_value(&ev)
                                .map_err(|x| io::Error::new(io::ErrorKind::InvalidData, x))?;
                            f.call::<LuaValue, Vec<String>>(value)
                                .map_err(|x| io::Error::new(io::ErrorKind::Other, x))
                        })
                    },
                    on_banner: {
                        let f: LuaFunction = tbl.get("on_banner")?;
                        Box::new(move |banner| {
                            let _ = f.call::<String, ()>(banner.to_string());
                        })
                    },
                    on_host_verify: {
                        let f: LuaFunction = tbl.get("on_host_verify")?;
                        Box::new(move |host| {
                            f.call::<String, bool>(host.to_string())
                                .map_err(|x| io::Error::new(io::ErrorKind::Other, x))
                        })
                    },
                    on_error: {
                        let f: LuaFunction = tbl.get("on_error")?;
                        Box::new(move |err| {
                            let _ = f.call::<String, ()>(err.to_string());
                        })
                    },
                },
                ssh: lua.from_value(tbl.get("ssh")?)?,
                timeout: {
                    let milliseconds: u64 = tbl.get("timeout")?;
                    Duration::from_millis(milliseconds)
                },
            }),
            LuaValue::Nil => Err(LuaError::FromLuaConversionError {
                from: "Nil",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Boolean(_) => Err(LuaError::FromLuaConversionError {
                from: "Boolean",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::LightUserData(_) => Err(LuaError::FromLuaConversionError {
                from: "LightUserData",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Integer(_) => Err(LuaError::FromLuaConversionError {
                from: "Integer",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Number(_) => Err(LuaError::FromLuaConversionError {
                from: "Number",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::String(_) => Err(LuaError::FromLuaConversionError {
                from: "String",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Function(_) => Err(LuaError::FromLuaConversionError {
                from: "Function",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Thread(_) => Err(LuaError::FromLuaConversionError {
                from: "Thread",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::UserData(_) => Err(LuaError::FromLuaConversionError {
                from: "UserData",
                to: "LaunchOpts",
                message: None,
            }),
            LuaValue::Error(_) => Err(LuaError::FromLuaConversionError {
                from: "Error",
                to: "LaunchOpts",
                message: None,
            }),
        }
    }
}

#[derive(Copy, Clone, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Method {
    Distant,
    Ssh,
}

impl Default for Method {
    fn default() -> Self {
        Self::Distant
    }
}
