#! /bin/bash

# usage:  e.g. ethdev=eth0 rev="5-2-stable" install-gitlab.sh

die() {
	message="${1}" ; shift
	errcd="${2}"   ; shift
	echo "${message}"
	exit ${errcd}
}

die "this script is NOT YET usable!!!" 1

case "$0" in
  /*) self=$0 ;;
  *) self=$(pwd)/$0 ;;
esac

selfdir=$( (cd "${self%/?*}" && pwd) )
[ "$selfdir" ] || exit 1

if [ $(id -u) != "0" ] ; then
	echo "This script must be run as user root"
	exit 1
fi

# the ethernet adapter to use

: ${ethdev:="eth0"}
: ${gituser:="git"}
: ${rev:="5-2-stable"}

: ${mysqluser:="root"}
: ${mysqlpass:="GhuP3412,bv"}

githome="/home/${gituser}"

# the list of Ubuntu packages to install
REQUIRED_PACKAGES="build-essential checkinstall curl gcc git git-core \
	libc6-dev libcurl4-openssl-dev libffi-dev libgdbm-dev libicu-dev \
	libncurses5-dev libreadline-dev libreadline6-dev libsqlite3-dev \
	libssl-dev libxml2-dev libxslt-dev libyaml-dev make openssh-server \
	postfix python-dev python-pip redis-server ruby1.9.3 sqlite3 sudo \
	vim zlib1g-dev"

# Shall we install MySQL server?  If yes, configure it automatically
# FIXME:  let user choose if he wants PostgreSQL instead?
echo -n "Shall ${0} install MySQL Server? [Y|n] " ; read install_mysql
install_mysql=$(echo "${install_mysql}" | tr "[:lower:]" "[:upper:]")
if [[ -z ${install_mysql} || ${install_mysql} == "Y" ]]; then
	REQUIRED_PACKAGES+=" mysql-common mysql-client mysql-server libmysqlclient-dev"
	# prepare for non-interactive configuration
	echo "mysql-server-5.5 mysql-server/root_password password ${mysqlpass}" | \
		debconf-set-selections
	echo "mysql-server-5.5 mysql-server/root_password_again password ${mysqlpass}" | \
		debconf-set-selections
fi

SUDO="sudo -H -u"

# install Ubuntu packages
echo "Installing required Ubuntu packages ... This might take a minute!"
(apt-get update && \
	apt-get upgrade -y > /dev/null 2>&1 && \
  apt-get install -y ${REQUIRED_PACKAGES}) || \
	echo "installation of required Ubuntu packages failed"

exit 1
# add needed git users
adduser --disabled-login --gecos 'GitLab' "${gituser}"

# install GitLab shell
#sudo su "${gituser}"
cd "${githome}"
${SUDO} "${gituser}" git clone https://github.com/gitlabhq/gitlab-shell.git
${SUDO} "${gituser}" test -d gitlab-shell && cd gitlab-shell
${SUDO} "${gituser}" git checkout v1.4.0 # required for 5.2.0
${SUDO} "${gituser}" cp config.yml.example config.yml # TODO
${SUDO} "${gituser}" chmod 0755 ./bin/install && ./bin/install

# MySQL setup

# ###################################################################
# TODO!!!!
# mysql -u root -p"${mysqlpass}" "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY ${mysqlpass}"
# mysql -u root -p \
# 	"CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`"
# mysql -u root -p \
# 	"GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'gitlab'@'localhost'"
# # Try connecting to the new database with the new user
# sudo -u git -H mysql -u gitlab -p -D gitlabhq_production
# ####################################################################

cd "${githome}"
${SUDO} "${gituser}" \
	git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd "${githome}/gitlab"
${SUDO} "${gituser}" git checkout "${rev}"

# Configure GitLab

cd "${githome}"
${SUDO} "${gituser}" cp config/gitlab.yml.example config/gitlab.yml
#${SUDO} "${gituser}" vim config/gitlab.yml ## TODO

mkdirs="${githome}/gitlab-satellites log tmp tmp/pids tmp/sockets public/uploads"
for dir in ${mkdirs} ; do
	${SUDO} "${gituser}" mkdir -p "${dir}" && \
		${SUDO} "${gituser}" chmod -R u+rwX "${dir}"
done

# Copy the example Puma config
${SUDO} "${gituser}" cp config/puma.rb.example config/puma.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
${SUDO} "${gituser}" git config --global user.name "GitLab"
${SUDO} "${gituser}" git config --global user.email "gitlab@localhost"

exit 1 # TODO

# generate RSA key

${SUDO} "${gitlabuser}" \
	"ssh-keygen -q -N '' -t rsa -f ${gitlabhome}/.ssh/id_rsa"
cp "${gitlabhome}/.ssh/id_rsa.pub" "${githome}/gitlab.pub"
chmod 0444 "${githome}/gitlab.pub"

# install gitolite
cd "${githome}"
${SUDO} "${gituser}" mkdir bin
${SUDO} "${gituser}" git clone -b gl-v304 \
	https://github.com/gitlabhq/gitolite.git gitolite-src
${SUDO} "${gituser}" \
	sh -c 'echo "PATH=\$PATH:${githome}/bin" >> ${githome}/.profile'
${SUDO} "${gituser}" \
	sh -c 'echo "export PATH" >> ${githome}/.profile'
${SUDO} "${gituser}" \
	gitolite-src/install -ln "${githome}/bin"
${SUDO} "${gituser}" \
	sh -c 'PATH=${githome}/bin:$PATH; gitolite setup -pk ${githome}/gitlab.pub'

chmod -R g+rwX "${githome}/repositories/"
chown -R "${gituser}":"${gituser}" "${githome}/repositories/"

# test the install
${SUDO} "${gitlabuser}" \
	git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
rm -rf /tmp/gitolite-admin

# install GitLab
gem install --conservative charlock_holmes --version '0.6.8'
pip install pygments
gem install --conservative bundler
cd "${gitlabhome}"

# clone GitLab
${SUDO} "${gitlabuser}" \
	git clone -b "${rev}" https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab

# config GitLab
${SUDO} "${gitlabuser}" \
	cp config/gitlab.yml.example config/gitlab.yml

# use SQLite (TODO: ??? really  ???)
${SUDO} "${gitlabuser}" \
	cp config/database.yml.sqlite config/database.yml

# install gems for database
${SUDO} "${gitlabuser}" \
	bundle install --without development test mysql postgres --deployment

# setup the db
${SUDO} "${gitlabuser}" \
	bundle exec rake gitlab:app:setup RAILS_ENV=production

# setup hooks
cp ./lib/hooks/post-receive \
	"${githome}/.gitolite/hooks/common/post-receive"
chown "${gituser}":"${gituser}" \
	"${githome}/.gitolite/hooks/common/post-receive"

# check status
echo "" ; echo "Checking install status ..." ; echo ""
${SUDO} "${gitlabuser}" \
	bundle exec rake gitlab:app:status RAILS_ENV=production

echo "" ; echo "Everything passed? Please type 'yes' or 'no'" ; echo ""
read GO_ON
if [ "${GO_ON}" != "yes" ] ; then
	echo "Your answer was not 'yes'.  Exiting."
	exit 1
fi

# test GitLab
echo "" ; echo "Succeeded." ; echo "Testing the installation"
cd "${gitlabhome}/gitlab"
${SUDO} "${gitlabuser}" bundle exec rails s -e production

echo ""
IP_ADDR=$(ifconfig ${ethdev} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }')
echo "Visit: $IP_ADDR:3000 from your browser, and login with:"
echo "admin@local.host	5iveL!fe"
echo ""
echo "NOTE: It will take a while to load the page the first time it is accessed,"
echo "due to compiling times on java-script, jquery core, and css files."
echo ""

# EOF
