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

: ${mysqluser:="gitlab"}
: ${mysqlpass:="gitlab,"}
: ${mysql_rootpass:="GhuP3412,bv"}

githome="/home/${gituser}"

# Generate RSA key

# ${SUDO} "${gituser}" \
# 	"ssh-keygen -q -N '' -t rsa -f ${githome}/.ssh/id_rsa"
# cp "${githome}/.ssh/id_rsa.pub" "${githome}/gitlab.pub"
# chmod 0444 "${githome}/gitlab.pub"

# the list of Ubuntu packages to install
REQUIRED_PACKAGES="build-essential checkinstall curl gcc git git-core \
	libc6-dev libcurl4-openssl-dev libffi-dev libgdbm-dev libicu-dev \
	libncurses5-dev libreadline-dev libreadline6-dev libsqlite3-dev \
	libssl-dev libxml2-dev libxslt-dev libyaml-dev make openssh-server \
	postfix python-dev python-pip redis-server ruby1.9.3 sqlite3 sudo \
	vim zlib1g-dev nginx"

# Shall we install MySQL server?  If yes, configure it automatically
# FIXME:  let user choose if he wants PostgreSQL instead?
echo -n "Shall ${0} install MySQL Server? [Y|n] " ; read install_mysql
install_mysql=$(echo "${install_mysql}" | tr "[:lower:]" "[:upper:]")
if [[ -z ${install_mysql} || ${install_mysql} == "Y" ]]; then
	REQUIRED_PACKAGES+=" mysql-common mysql-client mysql-server libmysqlclient-dev"
	# prepare for non-interactive configuration
	echo "mysql-server-5.5 mysql-server/root_password password ${mysql_rootpass}" | \
		debconf-set-selections
	echo "mysql-server-5.5 mysql-server/root_password_again password ${mysql_rootpass}" | \
		debconf-set-selections
fi

# TODO:  Request information for Postfix installation

SUDO="sudo -H -u"

# Install Ubuntu packages

echo "Installing required Ubuntu packages ... This might take a minute!"
( echo "apt-get update" && \
	apt-get update > /dev/null 2>&1 && \
	apt-get install -y ${REQUIRED_PACKAGES}
) || echo "installation of required Ubuntu packages failed"

# Install bundler
gem install --conservative bundler
pip install pygments

# Add git system user

adduser --disabled-login --gecos 'GitLab' "${gituser}"

# Install GitLab shell

cd "${githome}"
${SUDO} "${gituser}" git clone https://github.com/gitlabhq/gitlab-shell.git
${SUDO} "${gituser}" test -d gitlab-shell && cd gitlab-shell
${SUDO} "${gituser}" git checkout v1.4.0 # required for 5.2.0
${SUDO} "${gituser}" cp config.yml.example config.yml # TODO
${SUDO} "${gituser}" chmod 0755 ./bin/install && ./bin/install

# MySQL setup

if [[ -z ${install_mysql} || ${install_mysql} == "Y" ]]; then
	mysql -u root -p"${mysql_rootpass}" < create.sql
fi

# Get GitLab from github

cd "${githome}"
${SUDO} "${gituser}" \
	git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd "${githome}/gitlab"
${SUDO} "${gituser}" git checkout "${rev}"

# Configure GitLab

cd "${githome}/gitlab"
${SUDO} "${gituser}" cp config/gitlab.yml.example config/gitlab.yml
# FIXME
#${SUDO} "${gituser}" vim config/gitlab.yml ## TODO

mkdirs="${githome}/gitlab-satellites log tmp tmp/pids"
mkdirs="${mkdirs} tmp/sockets public/uploads"

for dir in ${mkdirs} ; do
	${SUDO} "${gituser}" mkdir -p "${dir}" && \
		${SUDO} "${gituser}" chmod -R u+rwX "${dir}"
done

# Copy the example Puma config

# FIXME: auto configuration
${SUDO} "${gituser}" cp config/puma.rb.example config/puma.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
${SUDO} "${gituser}" git config --global user.name "GitLab"
${SUDO} "${gituser}" git config --global user.email "gitlab@localhost"

# Setup GitLab for usage of MySQL (as preferred)

${SUDO} "${gituser}" cp config/database.yml.mysql config/database.yml

# Install Gems

charlock_holmes_ver='0.6.0.4'
cd "${githome}"
gem install charlock_holmes --version "${charlock_holmes_ver}"

# fix wrong file encoding!
f="${githome}/gitlab/vendor/bundle/ruby/1.9.1/specifications/gitlab-grit-2.5.1.gemspec"
iconv -f iso-8859-1 -t utf8 "${f}" "${f}_utf8"
rm "${f}"
mv "${f}_utf8" "${f}"

# fix utf8 typo!
cat "${f}" | sed s/s.add_runtime_depeîdency/s.add_runtime_dependency/g > "${f}_x"
rm "${f}"
mv "${f}_x" "${f}"

cd "${githome}/gitlab"
${SUDO} "${gituser}" bundle install --deployment --without development test postgres

# Initialize db

##### STOP HERE, CONFIGURE database.yml to match root PW!

echo "Set root password to ${mysql_rootpass} in ~git/gitlab/config/database.yml "
echo "and press return when done"
echo "" ; read

chown -R "${gituser}":"${gituser}" "${githome}/repositories/"
cd "${githome}/gitlab"
${SUDO} "${gituser}" bundle exec rake gitlab:setup RAILS_ENV=production
${SUDO} "${gituser}" bundle exec rake sidekiq:start RAILS_ENV=production

# Install Init Script

curl \
	--output "/etc/init.d/gitlab" \
		"https://raw.github.com/gitlabhq/gitlabhq/5-2-stable/lib/support/init.d/gitlab"
chmod +x /etc/init.d/gitlab

# TODO: make configurable
update-rc.d gitlab defaults 21

# Configure Nginx

curl \
	--output "/etc/nginx/sites-available/gitlab" \
		"https://raw.github.com/gitlabhq/gitlabhq/5-2-stable/lib/support/nginx/gitlab"
ln -s "/etc/nginx/sites-available/gitlab" "/etc/nginx/sites-enabled/gitlab"

# TODO!

# # **YOUR_SERVER_FQDN** to the fully-qualified
# # domain name of your host serving GitLab. Also, replace
# # the 'listen' line with the following:
# #   listen 80 default_server;         # e.g., listen 192.168.1.1:80;
# sudo vim /etc/nginx/sites-available/gitlab

# configure NGINX manually for the moment!

sudo service nginx restart

# Final testing

${SUDO} "${gituser}" bundle exec rake gitlab:env:info RAILS_ENV=production
${SUDO} "${gituser}" bundle exec rake gitlab:check RAILS_ENV=production

echo "" ; echo "Everything passed? [Y|n] " ; echo "" ; read passed
passed=$(echo "${passed}" | tr "[:lower:]" "[:upper:]")
if [ "${passed}" != "Y" ] ; then
	echo "Your answer was not 'yes'.  Exiting."
	exit 1
fi

echo "Starting GitLab service"
service gitlab start

echo ""
IP_ADDR=$(ifconfig ${ethdev} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }')
echo "Visit: $IP_ADDR from your browser, and login with:"
echo "admin@local.host	5iveL!fe"
echo ""
echo "NOTE: It will take a while to load the page the first time it is accessed,"
echo "due to compiling times on java-script, jquery core, and css files."
echo ""

# EOF
