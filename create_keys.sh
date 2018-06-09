# copied from /var/lib/dpkg/info/openssh-server.postinst
# adapted to take $path instead of /etc/ssh

get_config_option() {
        option="$1"
        path="$2"

        [ -f "$path/sshd_config" ] || return

        # TODO: actually only one '=' allowed after option
        perl -lne 's/\s+/ /g; print if s/^\s*'"$option"'[[:space:]=]+//i' \
           "$path/sshd_config"
}

host_keys_required() {
        path="$1"
        hostkeys="$(get_config_option HostKey $path)"
        if [ "$hostkeys" ]; then
                echo "$hostkeys"
        else
                # No HostKey directives at all, so the server picks some
                # defaults depending on the setting of Protocol.
                protocol="$(get_config_option Protocol)"
                [ "$protocol" ] || protocol=1,2
                if echo "$protocol" | grep 1 >/dev/null; then
                        echo $path/ssh_host_key
                fi
                if echo "$protocol" | grep 2 >/dev/null; then
                        echo $path/ssh_host_rsa_key
                        echo $path/ssh_host_dsa_key
                        echo $path/ssh_host_ecdsa_key
                        echo $path/ssh_host_ed25519_key
                fi
        fi
}

create_key() {
        msg="$1"
        shift
        hostkeys="$1"
        shift
        file="$1"
        shift

        if echo "$hostkeys" | grep -x "$file" >/dev/null && \
           [ ! -f "$file" ] ; then
                echo -n $msg
                ssh-keygen -q -f "$file" -N '' "$@"
                echo
                if which restorecon >/dev/null 2>&1; then
                        restorecon "$file" "$file.pub"
                fi
        fi
}

create_keys() {
        path="$1"
        hostkeys="$(host_keys_required $path)"

        create_key "Creating SSH1 key; this may take some time ..." \
                "$hostkeys" "$path/ssh_host_key" -t rsa1

        create_key "Creating SSH2 RSA key; this may take some time ..." \
                "$hostkeys" "$path/ssh_host_rsa_key" -t rsa
        create_key "Creating SSH2 DSA key; this may take some time ..." \
                "$hostkeys" "$path/ssh_host_dsa_key" -t dsa
        create_key "Creating SSH2 ECDSA key; this may take some time ..." \
                "$hostkeys" "$path/ssh_host_ecdsa_key" -t ecdsa
        create_key "Creating SSH2 ED25519 key; this may take some time ..." \
                "$hostkeys" "$path/ssh_host_ed25519_key" -t ed25519
}


