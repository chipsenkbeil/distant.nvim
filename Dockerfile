FROM --platform=linux/amd64 anatolelucet/neovim:0.8.0-ubuntu

# Install all of the packages we need
#
# 1. sudo for ability to run sshd as non-root user
# 2. openssh to be able to run sshd (and ssh as client)
# 3. bsdmainutils & make to use our makefile inside the container
# 4. git to be able to clone plenary for tests
# 5. curl & gzip to pull down lua-language-server
RUN DEBIAN_FRONTEND=noninteractive \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime \
    && apt update \
    && apt install -y --no-install-recommends \
        sudo \
        ca-certificates \
        openssh-client \
        openssh-server \
        bsdmainutils \
        make \
        git \
        curl \
        gzip

# Configure a test password
ARG DISTANT_PASSWORD=

# Configure a non-root user with a password that matches its name
# as we need a user with a password even when we are providing
# passwordless login via ssh
ARG user=docker
RUN addgroup --system $user \
    && adduser --system --home /home/$user --shell /bin/sh --ingroup $user $user \
    && echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$user \
    && chmod 0440 /etc/sudoers.d/$user \
    && test -n "$DISTANT_PASSWORD" \
        && echo "$user:$DISTANT_PASSWORD" | chpasswd \
        || echo "Password configured as empty"

ARG opt_dir=/opt
ARG opt_bin_dir=$opt_dir/bin
RUN mkdir -p $opt_bin_dir

# Install and configure lua language server
# NOTE: Must install to a path like /usr/bin as 
#       /usr/local/bin is not on path for ssh
ARG lua_language_server_release=https://github.com/LuaLS/lua-language-server/releases/download/3.6.21/lua-language-server-3.6.21-linux-x64.tar.gz
ARG opt_lsp_dir=$opt_dir/lua_language_server
RUN mkdir -p $opt_lsp_dir \
    && cd $opt_lsp_dir \
    && curl -L $lua_language_server_release | tar zx \
    && echo '#!/bin/bash' > $opt_bin_dir/lua-language-server \
    && echo "exec \"$opt_lsp_dir/bin/lua-language-server\" \"\$@\"" >> $opt_bin_dir/lua-language-server \
    && chmod +x $opt_bin_dir/lua-language-server \
    && ln -s $opt_bin_dir/lua-language-server /usr/local/bin/lua-language-server

# Install distant binary and make sure its in a path for everyone
ARG distant_version=0.20.0
ARG distant_host=x86_64-unknown-linux-musl
RUN curl -L sh.distant.dev | sh -s -- --install-dir "$opt_bin_dir" --distant-version $distant_version --distant-host $distant_host --run-as-admin \
    && ln -s "$opt_bin_dir/distant" /usr/local/bin/distant \
    && distant --version

USER $user
WORKDIR /home/$user

# Install and configure sshd with key using DISTANT_PASSWORD
#
# 1. Generate host keys
# 2. Generate client keys for user
# 3. Add client keys to accepted host keys for this user
# 4. Avoid needing to approve fingerprinting
RUN sudo mkdir -p /var/run/sshd \
    && sudo ssh-keygen -A \
    && ssh-keygen -q -m PEM -t rsa -N "$DISTANT_PASSWORD" -f /home/docker/.ssh/id_rsa \
    && cp /home/$user/.ssh/id_rsa.pub /home/$user/.ssh/authorized_keys \
    && echo 'StrictHostKeyChecking no' > /home/$user/.ssh/config

# Force ownership of binaries and opt path (needed for lua-language-server as it creates directories)
RUN sudo chown -R $user:$user $opt_dir

# Create path to neovim cache since it may not be created during tests
RUN mkdir -p /home/$user/.cache/nvim

# Install our repository within a subdirectory of home
COPY --chown=$user . app/

# By default, this will run the ssh server
CMD ["sudo", "/usr/sbin/sshd", "-D", "-e"]
