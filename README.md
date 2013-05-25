# gitlab-ubuntu

Script(s) for installation of latest GitLab revision on Ubuntu 13.04.
_Might work with Ubuntu 12.04 LTS as well_.

**Important**: This script is still highly under development!  Use
with caution!

## Execute

For example:

```bash
bash mysql_rootpass="foobar" ethdev="eth0" install-gitlab.sh
```
where

* eth0 is the ethernet device to use.  Default: eth0
* rev is the GitLab revision to install.  Default: 5-2-stable
* mysql_rootpass is the root password of your MySQL installation.
  If no MySQL is installed, yet, ommit setting this variable

## When installation is done

You can login to GitLab at the IP printed at the end of the
installation.  The default username is "admin@local.host" with
password "5iveL!fe".

# TODO

* Let the script configure GitLab for you (FQDN, Email, etc.).
* Give user more choices to setup GitLab.
* Give user choice to use PostgreSQL or MySQL
* …

## Project Overview

TBD
