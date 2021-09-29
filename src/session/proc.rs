use distant_core::{
    RemoteLspProcess as DistantRemoteLspProcess, RemoteProcess as DistantRemoteProcess,
};
use mlua::{prelude::*, UserData, UserDataFields, UserDataMethods};
use once_cell::sync::Lazy;
use std::{collections::HashMap, io, sync::RwLock};

/// Contains mapping of id -> remote process for use in maintaining active processes
static PROC_MAP: Lazy<RwLock<HashMap<usize, DistantRemoteProcess>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

/// Contains mapping of id -> remote lsp process for use in maintaining active processes
static LSP_PROC_MAP: Lazy<RwLock<HashMap<usize, DistantRemoteLspProcess>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

macro_rules! with_proc {
    ($map_name:ident, $id:expr, $proc:ident -> $f:expr) => {{
        let id = $id;
        let mut lock = $map_name.write().map_err(|x| x.to_string().to_lua_err())?;
        let $proc = lock.get_mut(&id).ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::NotFound,
                format!("No remote process found with id {}", id),
            )
            .to_lua_err()
        })?;
        $f
    }};
}

#[derive(Copy, Clone, Debug)]
pub struct RemoteProcess {
    id: usize,
}

impl RemoteProcess {
    pub fn new(id: usize) -> Self {
        Self { id }
    }

    pub fn from_distant(proc: DistantRemoteProcess) -> LuaResult<Self> {
        let id = proc.id();
        PROC_MAP
            .write()
            .map_err(|x| x.to_string().to_lua_err())?
            .insert(id, proc);
        Ok(Self::new(id))
    }

    pub fn is_active(&self) -> LuaResult<bool> {
        Ok(PROC_MAP
            .read()
            .map_err(|x| x.to_string().to_lua_err())?
            .contains_key(&self.id))
    }

    pub async fn write_stdin(&self, data: String) -> LuaResult<()> {
        with_proc!(PROC_MAP, self.id, proc -> {
            proc.stdin
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stdin closed").to_lua_err()
                })?
                .write(data)
                .await
                .to_lua_err()
        })
    }

    pub async fn read_stdout(&self) -> LuaResult<String> {
        with_proc!(PROC_MAP, self.id, proc -> {
            proc.stdout
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stdout closed").to_lua_err()
                })?
                .read()
                .await
                .to_lua_err()
        })
    }

    pub async fn read_stderr(&self) -> LuaResult<String> {
        with_proc!(PROC_MAP, self.id, proc -> {
            proc.stderr
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stderr closed").to_lua_err()
                })?
                .read()
                .await
                .to_lua_err()
        })
    }

    pub async fn kill(&self) -> LuaResult<()> {
        with_proc!(PROC_MAP, self.id, proc -> {
            proc.kill().await.to_lua_err()
        })
    }

    pub fn abort(&self) -> LuaResult<()> {
        with_proc!(PROC_MAP, self.id, proc -> {
            Ok(proc.abort())
        })
    }
}

impl UserData for RemoteProcess {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("id", |_, this| Ok(this.id));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("is_active", |_, this, _: LuaValue| this.is_active());
        methods.add_async_method("write_stdin", |_, this, data: String| async move {
            this.write_stdin(data).await
        });
        methods.add_async_method("read_stdout", |_, this, _: LuaValue| async move {
            this.read_stdout().await
        });
        methods.add_async_method("read_stderr", |_, this, _: LuaValue| async move {
            this.read_stderr().await
        });
        methods.add_async_method(
            "kill",
            |_, this, _: LuaValue| async move { this.kill().await },
        );
        methods.add_method("abort", |_, this, _: LuaValue| this.abort());
    }
}

#[derive(Copy, Clone, Debug)]
pub struct RemoteLspProcess {
    id: usize,
}

impl RemoteLspProcess {
    pub fn new(id: usize) -> Self {
        Self { id }
    }

    pub fn from_distant(proc: DistantRemoteLspProcess) -> LuaResult<Self> {
        let id = proc.id();
        LSP_PROC_MAP
            .write()
            .map_err(|x| x.to_string().to_lua_err())?
            .insert(id, proc);
        Ok(Self::new(id))
    }

    pub fn is_active(&self) -> LuaResult<bool> {
        Ok(LSP_PROC_MAP
            .read()
            .map_err(|x| x.to_string().to_lua_err())?
            .contains_key(&self.id))
    }

    pub async fn write_stdin(&self, data: String) -> LuaResult<()> {
        with_proc!(LSP_PROC_MAP, self.id, proc -> {
            proc.stdin
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stdin closed").to_lua_err()
                })?
                .write(data.as_str())
                .await
                .to_lua_err()
        })
    }

    pub async fn read_stdout(&self) -> LuaResult<String> {
        with_proc!(LSP_PROC_MAP, self.id, proc -> {
            proc.stdout
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stdout closed").to_lua_err()
                })?
                .read()
                .await
                .to_lua_err()
        })
    }

    pub async fn read_stderr(&self) -> LuaResult<String> {
        with_proc!(LSP_PROC_MAP, self.id, proc -> {
            proc.stderr
                .as_mut()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::BrokenPipe, "Stderr closed").to_lua_err()
                })?
                .read()
                .await
                .to_lua_err()
        })
    }

    pub async fn kill(&self) -> LuaResult<()> {
        with_proc!(LSP_PROC_MAP, self.id, proc -> {
            proc.kill().await.to_lua_err()
        })
    }

    pub fn abort(&self) -> LuaResult<()> {
        with_proc!(PROC_MAP, self.id, proc -> {
            Ok(proc.abort())
        })
    }
}

impl UserData for RemoteLspProcess {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("id", |_, this| Ok(this.id));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("is_active", |_, this, _: LuaValue| this.is_active());
        methods.add_async_method("write_stdin", |_, this, data: String| async move {
            this.write_stdin(data).await
        });
        methods.add_async_method("read_stdout", |_, this, _: LuaValue| async move {
            this.read_stdout().await
        });
        methods.add_async_method("read_stderr", |_, this, _: LuaValue| async move {
            this.read_stderr().await
        });
        methods.add_async_method(
            "kill",
            |_, this, _: LuaValue| async move { this.kill().await },
        );
        methods.add_method("abort", |_, this, _: LuaValue| this.abort());
    }
}
