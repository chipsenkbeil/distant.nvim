use distant_ssh2::Ssh2SessionOpts;
use mlua::prelude::*;
use serde::Deserialize;
use std::{path::PathBuf, time::Duration};

#[derive(Clone, Debug, Deserialize)]
#[serde(default)]
pub struct LaunchOpts<'lua> {
    pub host: String,
    pub method: Method,
    pub on_authenticate: LuaFunction<'lua>,
    pub on_host_verify: LuaFunction<'lua>,
    pub ssh: SshOpts,
    pub timeout: Duration,
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

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default)]
pub struct SshOpts {
    pub identity_files: Vec<PathBuf>,
    pub identities_only: Option<bool>,
    pub port: Option<u16>,
    pub proxy_command: Option<String>,
    pub user: Option<String>,
    pub user_known_hosts_files: Vec<PathBuf>,
}

impl From<SshOpts> for Ssh2SessionOpts {
    fn from(ssh_opts: SshOpts) -> Self {
        Self {
            identity_files: ssh_opts.identity_files,
            identities_only: ssh_opts.identities_only,
            port: ssh_opts.port,
            proxy_command: ssh_opts.proxy_command,
            user: ssh_opts.user,
            user_known_hosts_files: ssh_opts.user_known_hosts_files,
        }
    }
}
