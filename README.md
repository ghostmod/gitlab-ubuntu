# gitlab-ubuntu

Script(s) for installation of latest GitLab revision on Ubuntu 13.04.
_Might work with Ubuntu 12.04 LTS as well_.

**First shot.  I've finished to install a GitLab 5.2.0 into a fresh
Ubuntu 13.04.  Not fully -- still needed some hands on in the config.
But we are getting closer**

**Important**: This script is still highly under development!  Use
with caution!

## Execute

For example:

```bash
ethdev="eth0" rev="5-2-stable" install-gitlab.sh
```

where

* eth0 is the ethernet device to use.  Default: eth0
* rev is the GitLab revision to install.  Default: 5-2-stable

# TODO

* Let the script configure GitLab for you (FQDN, Email, etc.)
* …

## Project Overview

TBD
