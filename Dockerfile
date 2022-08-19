FROM --platform=linux/amd64 anatolelucet/neovim:0.7.0-ubuntu

# Install all of the packages we need
#
# 1. sudo for ability to run sshd as non-root user
# 2. openssh to be able to run sshd (and ssh as client)
# 3. build-base to be able to build the distant binary
# 4. git to be able to clone plenary for tests
# 5. curl & gzip to pull down rust-analyzer
RUN DEBIAN_FRONTEND=noninteractive \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime \
    && apt update \
    && apt install -y --no-install-recommends \
        sudo \
        ca-certificates \
        openssh-client \
        openssh-server \
        build-essential \
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
USER $user
WORKDIR /home/$user

ARG cargo_bin_dir=/home/$user/.cargo/bin
RUN mkdir -p $cargo_bin_dir

# Install and configure rust & rls
# NOTE: Must install to a path like /usr/bin as 
#       /usr/local/bin is not on path for ssh
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . /home/$user/.cargo/env \
    && rustup component add rls \
    && sudo ln -s $cargo_bin_dir/rls /usr/bin/rls

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

ARG DISTANT_VERSION=0.18.0

# Install distant binary and make sure its in a path for everyone
ARG distant_release=https://github.com/chipsenkbeil/distant/releases/download/v$DISTANT_VERSION
RUN curl -L $distant_release/distant-linux64-gnu > $cargo_bin_dir/distant \
    && chmod +x $cargo_bin_dir/distant \
    && sudo ln -s $cargo_bin_dir/distant /usr/local/bin/distant

# Install our repository within a subdirectory of home
COPY --chown=$user . app/

# By default, this will run the ssh server
CMD ["sudo", "/usr/sbin/sshd", "-D", "-e"]
