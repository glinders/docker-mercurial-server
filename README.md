# [mercurial-server](http://www.lshift.net/work/open-source/mercurial-server/) for Docker

The repositories are in  `/var/lib/mercurial-server/repos`

It will generate SSH keys and place them in repository `sshd_keys` and create the `hgadmin` repository. 
It will only create the repos if they are not there.

First time use (add your SSH keys as the `hgadmin` root keys):

    docker run -v <repos>:/var/lib/mercurial-server/repos -p 8022:8022 -e HG_ROOTUSER_KEYS="$(ssh-add -L)" <image>

Later uses:

    docker run -v <repos>:/var/lib/mercurial-server/repos -p 8022:8022 <image>

Option `-v <repos>:/var/lib/mercurial-server/repos` is omnly needed if you want to mount the repos on a separate volume.
If you mount a volume in your container, make sure that it is writable by user `hg`:

    chown -R 106:107 <volume>


All configuration is done through the hgadmin repository, as explained in the file `/usr/share/doc/mercurial-server/html/index.html`.

    hg clone ssh://hg@localhost:8022/hgadmin
    cd hgadmin
    # change config
    hg push


## Use the `Makefile` to build and run mercurial-server

Build: `make build`

Run: `make run`

To add an initial root key, `make run` must be executed by a user with a key agent running.
To check for that, run: `ssh-add -L`

Also possible is:

    sudo bash -c "cd /root/docker/mercurial-server; make run"



