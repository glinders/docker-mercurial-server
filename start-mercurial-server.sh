#!/bin/bash

# include some functions to create our keys
. /create_keys.sh

# some path variables
MS_BASE_PATH=/var/lib/mercurial-server
MS_REPOS_PATH=$MS_BASE_PATH/repos
MS_KEYS_PATH=$MS_REPOS_PATH/sshd_keys
MS_SSHD_CONFIG=$MS_KEYS_PATH/sshd_config
ROOT_KEYS_PATH=/etc/ssh
ROOT_SSHD_CONFIG=$ROOT_KEYS_PATH/sshd_config
HGADMIN_PATH=$MS_REPOS_PATH/hgadmin

# we exit here in case we find a fault
die() {
     msg="$1"
     echo $msg >&2
     exit 1
}

# log hg version
hg version --verbose

# create and configure hgadmin repo
if [ ! -d "$HGADMIN_PATH" ]; then
    echo "creating hgadmin repo"
    [ -w "$(dirname "$HGADMIN_PATH")" ] || die "$(dirname "$HGADMIN_PATH") is not writable by user $(id)"
    hg init "$HGADMIN_PATH"
    # add keys passsed from user (if any)
    if [ -n "$HG_ROOTUSER_KEYS" ]; then
        mkdir -p keys/root/firstboot
        echo "$HG_ROOTUSER_KEYS" > keys/root/firstboot/initial_keys
    fi
fi

# now configure it
pushd "$HGADMIN_PATH" > /dev/null

if [ ! -f access.conf ]; then
    echo "creating access.conf"
    touch access.conf
fi

if [ ! -f .hg/hgrc ]; then
    echo "creating hgrc"
    cat > .hg/hgrc << EOF
# WARNING: when these hooks run they will entirely destroy and rewrite
# ~/.ssh/authorized_keys

[extensions]
hgext.purge =

[hooks]
changegroup.aaaab_update = hg update -C default > /dev/null
changegroup.aaaac_purge = hg purge --all > /dev/null
changegroup.refreshauth = python:mercurialserver.refreshauth.hook
EOF
fi
if [ ! -f .hg/hgrc ]; then
    die "Could not create hgadmin hooks"
fi
hg commit -A -m "created hgadmin repo" -u "$(id)"
chown -R hg: .
popd > /dev/null

if [ -n "$HG_ROOTUSER_KEYS" ]; then
    echo "Adding some keys as temporary root user keys:"
    echo "$HG_ROOTUSER_KEYS"
    mkdir -p /etc/mercurial-server/keys/root/bootkey
    echo "$HG_ROOTUSER_KEYS" > /etc/mercurial-server/keys/root/bootkey/temp_keys
fi

# create and configure sshd keys repo (if not there)
if [ ! -d "$MS_KEYS_PATH" ]; then
    echo "create and configure sshd keys repo"
    [ -w "$(dirname $MS_KEYS_PATH)" ] || die "$(dirname $MS_KEYS_PATH) is not writable by user $(id)"
    hg init "$MS_KEYS_PATH"

    pushd "$MS_KEYS_PATH" > /dev/null
    sed "s@$ROOT_KEYS_PATH/@$MS_KEYS_PATH/@g" "$ROOT_SSHD_CONFIG" > "$MS_SSHD_CONFIG"
    [ -f "$MS_SSHD_CONFIG" ] || die "Could not create $MS_SSHD_CONFIG"

    create_keys "$MS_KEYS_PATH"
    # keys must be r/w for owner only
    chmod -R go-rwx .
    hg commit -A -m "created sshd keys for user $(id)" -u "$(id)"
    chown -R hg: .
    popd > /dev/null
fi

# ensure authorised_keys is set up for us
/usr/share/mercurial-server/refresh-auth &

exec /usr/sbin/sshd -D \
  -e \
  -o PidFile=none \
  -f "$MS_SSHD_CONFIG" \
  -p 8022
