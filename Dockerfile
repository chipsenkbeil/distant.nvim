FROM --platform=linux/amd64 alpine:3.14

# Install all of the packages we need
#
# 1. sudo for ability to run sshd as non-root user
# 2. openssh & openrc to be able to run sshd (and ssh as client)
# 3. build-base & rustup to be able to build the distant binary
# 4. git to be able to clone plenary for tests
# 5. curl & gzip to pull down rust-analyzer
RUN apk add --update --no-cache \
    sudo \
    openssh openrc \
    build-base rustup \
    git \
    curl gzip

# Configure a non-root user with a password that matches its name
# as we need a user with a password even when we are providing
# passwordless login via ssh
ARG user=docker
RUN addgroup -S $user \
    && adduser --home /home/$user -s /bin/sh -S $user -G $user \
    && adduser $user wheel \
    && echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$user \
    && chmod 0440 /etc/sudoers.d/$user \
    && echo "$user:$user" | chpasswd
USER $user
WORKDIR /home/$user

ARG cargo_bin_dir=/home/$user/.cargo/bin
RUN mkdir -p $cargo_bin_dir

# Install and configure rust & rls
RUN rustup-init -y \
    && source /home/$user/.cargo/env \
    && rustup component add rls \
    && sudo ln -s $cargo_bin_dir/rls /usr/local/bin/rls

# Install neovim 0.5 binary (from edge)
RUN sudo apk add neovim \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/

# Install and configure sshd
#
# 1. Support openrc not being properly ready (touch softlevel)
# 2. Generate host keys
# 3. Add the service to be able to run it
# 4. Generate client keys for user
# 5. Add client keys to accepted host keys for this user
# 6. Avoid needing to approve fingerprinting
RUN sudo mkdir -p /var/run/sshd /run/openrc \
    && sudo touch /run/openrc/softlevel \
    && sudo ssh-keygen -A \
    && sudo rc-update add sshd \
    && ssh-keygen -q -t rsa -N '' -f /home/docker/.ssh/id_rsa \
    && cp /home/$user/.ssh/id_rsa.pub /home/$user/.ssh/authorized_keys \
    && echo 'StrictHostKeyChecking no' > /home/$user/.ssh/config

# Install distant binary and make sure its in a path for everyone
ARG distant_release=https://github.com/chipsenkbeil/distant/releases/download/v0.13.1
RUN curl -L $distant_release/distant-linux64-musl > $cargo_bin_dir/distant \
    && chmod +x $cargo_bin_dir/distant \
    && sudo ln -s $cargo_bin_dir/distant /usr/local/bin/distant

# Install our repository within a subdirectory of home
COPY --chown=$user . app/

# By default, this will run the ssh server
CMD ["sudo", "/usr/sbin/sshd", "-D", "-e"]
