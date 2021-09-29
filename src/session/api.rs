use distant_core::{
    DirEntry, Error as Failure, Metadata, RemoteLspProcess, RemoteProcess, SessionChannel,
    SessionChannelExt,
};
use mlua::prelude::*;
use once_cell::sync::Lazy;
use paste::paste;
use serde::Deserialize;
use std::{path::PathBuf, time::Duration};

static TENANT: Lazy<String> = Lazy::new(|| format!("{}", whoami::hostname()));

// Default timeout in milliseconds (15 secs)
const fn default_timeout() -> u64 {
    15000
}

macro_rules! make_api {
    (
        $name:ident,
        $ret:ty,
        {$($pname:ident: $ptype:ty),*},
        |$channel:ident, $tenant:ident, $params:ident| $block:block $(,)?
    ) => {
        paste! {
            #[derive(Clone, Debug, Deserialize)]
            pub struct [<$name:camel Params>] {
                $($pname: $ptype,)*

                #[serde(default = "default_timeout")]
                timeout: u64,
            }

            impl [<$name:camel Params>] {
                fn to_timeout_duration(&self) -> Duration {
                    Duration::from_millis(self.timeout)
                }
            }

            pub fn [<$name:snake _sync>](
                channel: SessionChannel,
                params: [<$name:camel Params>],
            ) -> LuaResult<$ret> {
                let rt = crate::runtime::get()?;
                rt.block_on([<$name:snake>](channel, params))
            }

            pub async fn [<$name:snake>](
                channel: SessionChannel,
                params: [<$name:camel Params>],
            ) -> LuaResult<$ret> {
                try_timeout!(params.to_timeout_duration(), async move {
                    let f = |
                        mut $channel: SessionChannel,
                        $tenant: &'static str,
                        $params: [<$name:camel Params>]
                    | async move $block;
                    f(channel, TENANT.as_str(), params).await
                })
            }
        }
    };
}

make_api!(append_file, (), { path: PathBuf, data: Vec<u8> }, |channel, tenant, params| {
    channel.append_file(tenant, params.path, params.data).await
});

make_api!(append_file_text, (), { path: PathBuf, data: String }, |channel, tenant, params| {
    channel.append_file_text(tenant, params.path, params.data).await
});

make_api!(copy, (), { src: PathBuf, dst: PathBuf }, |channel, tenant, params| {
    channel.copy(tenant, params.src, params.dst).await
});

make_api!(create_dir, (), { path: PathBuf, all: bool }, |channel, tenant, params| {
    channel.create_dir(tenant, params.path, params.all).await
});

make_api!(
    exists,
    bool,
    { path: PathBuf },
    |channel, tenant, params| { channel.exists(tenant, params.path).await }
);

make_api!(
    metadata,
    Metadata,
    { path: PathBuf, canonicalize: bool, resolve_file_type: bool },
    |channel, tenant, params| {
        channel.metadata(
            tenant,
            params.path,
            params.canonicalize,
            params.resolve_file_type
        ).await
    }
);

make_api!(
    read_dir,
    (Vec<DirEntry>, Vec<Failure>),
    { path: PathBuf, depth: usize, absolute: bool, canonicalize: bool, include_root: bool },
    |channel, tenant, params| {
        channel.read_dir(
            tenant,
            params.path,
            params.depth,
            params.absolute,
            params.canonicalize,
            params.include_root,
        ).await
    }
);

make_api!(
    read_file,
    Vec<u8>,
    { path: PathBuf },
    |channel, tenant, params| { channel.read_file(tenant, params.path).await }
);

make_api!(
    read_file_text,
    String,
    { path: PathBuf },
    |channel, tenant, params| { channel.read_file_text(tenant, params.path).await }
);

make_api!(
    remove,
    (),
    { path: PathBuf, force: bool },
    |channel, tenant, params| { channel.remove(tenant, params.path, params.force).await }
);

make_api!(
    rename,
    (),
    { src: PathBuf, dst: PathBuf },
    |channel, tenant, params| { channel.rename(tenant, params.src, params.dst).await }
);

make_api!(
    spawn,
    RemoteProcess,
    { cmd: String, args: Vec<String> },
    |channel, tenant, params| { channel.spawn(tenant, params.cmd, params.args).await }
);

make_api!(
    spawn_lsp,
    RemoteLspProcess,
    { cmd: String, args: Vec<String> },
    |channel, tenant, params| { channel.spawn_lsp(tenant, params.cmd, params.args).await }
);

make_api!(
    write_file,
    (),
    { path: PathBuf, data: Vec<u8> },
    |channel, tenant, params| { channel.write_file(tenant, params.path, params.data).await }
);

make_api!(
    write_file_text,
    (),
    { path: PathBuf, data: String },
    |channel, tenant, params| { channel.write_file_text(tenant, params.path, params.data).await }
);
