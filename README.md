# gitlab-ubuntu

Script(s) for installation of latest GitLab revision on Ubuntu 13.04.
_Might work with Ubuntu 12.04 LTS as well_.

**Important**: This script is still under development!  Use with caution!

## Execute

For example:

```bash
git clone https://github.com/johndoe75/gitlab-ubuntu.git
cd gitlab-ubuntu
sudo bash ethdev="eth0" gituser="git" \
	rev="5-2-stable" mysqluser="gitlab" \
	mysqlpass="gitlab," mysql_rootpass="GhuP3412,bv" \
	install-gitlab.sh
```

Any of the variables can be omitted.  If you just want to install with defaults, just execute:

```bash
git clone https://github.com/johndoe75/gitlab-ubuntu.git
cd gitlab-ubuntu
sudo bash install-gitlab.sh
```

* {ethdev} is the ethernet device to use (Nginx)
* {rev} is the gitlab revision to install (e.g. 5-2-stable)
* {mysqluser} is the GitLab MySQL user
* {mysqlpass} is the GitLab MySQL password
* {mysql_rootpass} is the root password of your MySQL installation.  If no MySQL is installed yet on your system, omit this variable.

If specify the mysql_rootpass, but don't want it to be stored in your bash history, just execute:

```bash
unset HISTFILE
```
prior executing the installation script.

**Important**: This script *must* be run as bash script.  Don't use dash,
don't use sh!

## When installation is done

The IP where the webserver is running, is printed at the end of the installation.  The default GitLab admin username and password are "admin@local.host", "5liveL!fe".

# TODO

* Let the script configure GitLab for you (FQDN, Email, etc.).
* Give user more choices to setup GitLab.
* Give user choice to use PostgreSQL or MySQL
* …

## Project Overview

TBD
