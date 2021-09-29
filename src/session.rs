use distant_core::{
    Session as DistantSession, SessionChannel, SessionChannelExt, SessionInfo,
    XChaCha20Poly1305Codec,
};
use distant_ssh2::{Ssh2AuthHandler, Ssh2Session};
use mlua::{prelude::*, LuaSerdeExt, UserData, UserDataFields, UserDataMethods};
use once_cell::sync::Lazy;
use paste::paste;
use std::{collections::HashMap, io, sync::RwLock};

/// try_timeout!(timeout: Duration, Future<Output = Result<T, E>>) -> LuaResult<T>
macro_rules! try_timeout {
    ($timeout:expr, $f:expr) => {{
        use mlua::prelude::*;
        let timeout: std::time::Duration = $timeout;
        let fut = async move { $f };

        tokio::select! {
            _ = tokio::time::sleep(timeout) => {
                let err = std::io::Error::new(
                    std::io::ErrorKind::TimedOut,
                    format!("Reached timeout of {}s", timeout.as_secs_f32())
                );
                Err(err.to_lua_err())
            }
            res = fut.await => {
                res.to_lua_err()
            }
        }
    }};
}

mod api;
mod opts;
mod proc;

pub use opts::LaunchOpts;
use opts::Method;
use proc::{RemoteLspProcess, RemoteProcess};

/// Contains mapping of id -> session for use in maintaining active sessions
static SESSION_MAP: Lazy<RwLock<HashMap<usize, DistantSession>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

fn get_session_channel(id: usize) -> LuaResult<SessionChannel> {
    let lock = SESSION_MAP.read().map_err(|x| x.to_string().to_lua_err())?;
    let session = lock.get(&id).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotConnected,
            format!("No session connected with id {}", id),
        )
        .to_lua_err()
    })?;

    Ok(session.clone_channel())
}

/// Holds a reference to the session to perform remote operations
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct Session {
    id: usize,
}

impl Session {
    /// Creates a new session referencing the given distant session with the specified id
    pub fn new(id: usize) -> Self {
        Self { id }
    }

    /// Launches a new distant session on a remote machine
    // pub async fn launch(ssh_opts: SshOpts) -> LuaResult {}
    pub async fn launch(opts: LaunchOpts) -> LuaResult<Self> {
        let LaunchOpts {
            host,
            method,
            ssh,
            on_authenticate,
            on_host_verify,
            timeout,
        } = opts;

        // First, establish a connection to an SSH server
        let ssh_session = Ssh2Session::connect(host, ssh.into()).to_lua_err()?;

        // Second, authenticate with the server and get a session that is powered by SSH
        let session = ssh_session
            .authenticate(Ssh2AuthHandler {
                /* pub on_authenticate: Box<dyn FnMut(Ssh2AuthEvent) -> io::Result<Vec<String>>>,
                pub on_banner: Box<dyn FnMut(&str)>,
                pub on_host_verify: Box<dyn FnMut(&str) -> io::Result<bool>>, */
            })
            .await
            .to_lua_err()?;

        // Third, if the actual method we want is distant, then we use our current session to
        // spawn distant and then swap out our session with that one
        //
        // Otherwise, we just return this session as is
        let session = match method {
            Method::Distant => {
                // TODO: Provide spawn arguments
                let mut proc = session
                    .spawn("", "distant", Vec::new())
                    .await
                    .to_lua_err()?;
                let mut stdout = proc.stdout.take().unwrap();
                let (success, code) = proc.wait().await.to_lua_err()?;
                session.abort();

                if success {
                    // TODO: Does this work post-success?
                    let mut out = String::new();
                    while let Ok(data) = stdout.read().await {
                        out.push_str(&data);
                    }
                    let maybe_info = out
                        .lines()
                        .find_map(|line| line.parse::<SessionInfo>().ok());
                    match maybe_info {
                        Some(info) => {
                            let addr = info.to_socket_addr().await.to_lua_err()?;
                            let key = todo!();
                            let codec = XChaCha20Poly1305Codec::from(key);
                            DistantSession::tcp_connect_timeout(addr, codec, timeout)
                                .await
                                .to_lua_err()?;
                        }
                        None => {
                            return Err(io::Error::new(
                                io::ErrorKind::InvalidData,
                                "Missing session data",
                            )
                            .to_lua_err())
                        }
                    }
                } else {
                    return Err(io::Error::new(
                        io::ErrorKind::BrokenPipe,
                        format!(
                            "Spawning distant failed: {}",
                            code.map(|x| x.to_string())
                                .unwrap_or_else(|| String::from("???"))
                        ),
                    )
                    .to_lua_err());
                }
            }
            Method::Ssh => session,
        };

        // Fourth, store our current session in our global map and then return a reference
        let id = oorandom::Rand32::rand_u32() as usize;
        SESSION_MAP
            .write()
            .map_err(|x| x.to_string().to_lua_err())?
            .insert(id, session);
        Ok(Self::new(id))
    }
}

/// impl_methods!(methods: &mut M, name: Ident)
macro_rules! impl_methods {
    ($methods:expr, $name:ident) => {
        impl_methods!($methods, $name, |_lua, data| {Ok(data)});
    };
    ($methods:expr, $name:ident, |$lua:ident, $data:ident| $block:block) => {{
        paste! {
            $methods.add_method(stringify!([<$name:snake _sync>]), |$lua, this, params: LuaValue| {
                let params: api::[<$name:camel Params>] = $lua.from_value(params)?;
                let $data = api::[<$name:snake _sync>](get_session_channel(this.id)?, params)?;

                #[allow(unused_braces)]
                $block
            });
            $methods.add_async_method(stringify!([<$name:snake>]), |$lua, this, params: LuaValue| async move {
                let params: api::[<$name:camel Params>] = $lua.from_value(params)?;
                let $data = api::[<$name:snake>](get_session_channel(this.id)?, params).await?;

                #[allow(unused_braces)]
                $block
            });
        }
    }};
}

impl UserData for Session {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("id", |_, this| Ok(this.id));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("is_active", |_, this, _: LuaValue| {
            Ok(get_session_channel(this.id).is_ok())
        });

        impl_methods!(methods, append_file);
        impl_methods!(methods, append_file_text);
        impl_methods!(methods, copy);
        impl_methods!(methods, create_dir);
        impl_methods!(methods, exists);
        impl_methods!(methods, metadata, |lua, m| { lua.to_value(&m) });
        impl_methods!(methods, read_dir, |lua, results| {
            let (entries, errors) = results;
            let tbl = lua.create_table()?;
            tbl.set(
                "entries",
                entries
                    .iter()
                    .map(|x| lua.to_value(x))
                    .collect::<LuaResult<Vec<LuaValue>>>()?,
            )?;
            tbl.set(
                "errors",
                errors
                    .iter()
                    .map(|x| x.to_string())
                    .collect::<Vec<String>>(),
            )?;

            Ok(tbl)
        });
        impl_methods!(methods, read_file);
        impl_methods!(methods, read_file_text);
        impl_methods!(methods, remove);
        impl_methods!(methods, rename);
        impl_methods!(methods, spawn, |_lua, proc| {
            Ok(RemoteProcess::from_distant(proc))
        });
        impl_methods!(methods, spawn_lsp, |_lua, proc| {
            Ok(RemoteLspProcess::from_distant(proc))
        });
        impl_methods!(methods, write_file);
        impl_methods!(methods, write_file_text);
    }
}
