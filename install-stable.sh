#! /bin/bash

# usage:  e.g. ethdev=eth0 rev="5-2-stable" install-gitlab.sh

case "$0" in
  /*) self=$0 ;;
  *) self=$(pwd)/$0 ;;
esac

selfdir=$( (cd "${self%/?*}" && pwd) )
[ "$selfdir" ] || exit 1

if [ "${UID}" != 0 ] ; then
	echo "This script must be run as user root"
	exit 1
fi

# the ethernet adapter to use
: ${ethdev:="eth0"}
: ${gituser:="git"}
: ${gitlabuser:="gitlab"}

# the list of Ubuntu packages to install
REQUIRED_PACKAGES="git git-core gcc libxml2-dev libxslt-dev sqlite3 \
  libsqlite3-dev libcurl4-openssl-dev libreadline6-dev libc6-dev \
  libssl-dev make build-essential zlib1g-dev libicu-dev redis-server \
  openssh-server python-dev python-pip libyaml-dev postfix ruby1.9.3"

SUDO="sudo -H -u"
ETH_ADAPTER="eth0"

# install Ubuntu packages
apt-get install -y "${REQUIRED_PACKAGES}"

# add needed git users
adduser --system --shell /bin/bash --gecos 'git user' --group \
	--disabled-password --home "/home/${gituser}" "${gituser}"
adduser --disabled-login --gecos 'gitlab system user' "${gitlabuser}"

# exchange user groups
usermod -a -G "${gituser}" "${gitlabuser}"
usermod -a -G "${gitlabuser}" "${gituser}"

# generate RSA key
gitlabhome="/home/${gitlabuser}"
githome="/home/${gituser}"

"${SUDO}" "${gitlabuser}" \
	"ssh-keygen -q -N '' -t rsa -f ${gitlabhome}/.ssh/id_rsa"
cp "${gitlabhome}/.ssh/id_rsa.pub" "${githome}/gitlab.pub"
chmod 0444 "${githome}/gitlab.pub"

# install gitolite
cd "${githome}"
"${SUDO}" "${gituser}" mkdir bin
"${SUDO}" "${gituser}" git clone -b gl-v304 \
	https://github.com/gitlabhq/gitolite.git gitolite-src
"${SUDO}" "${gituser}" \
	sh -c 'echo "PATH=\$PATH:${githome}/bin" >> ${githome}/.profile'
"${SUDO}" "${gituser}" \
	sh -c 'echo "export PATH" >> ${githome}/.profile'
"${SUDO}" "${gituser}" \
	gitolite-src/install -ln "${githome}/bin"
"${SUDO}" "${gituser}" \
	sh -c 'PATH=${githome}/bin:$PATH; gitolite setup -pk ${githome}/gitlab.pub'

chmod -R g+rwX "${githome}/repositories/"
chown -R "${gituser}":"${gituser}" "${githome}/repositories/"

# test the install
"${SUDO}" "${gitlabuser}" \
	git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
rm -rf /tmp/gitolite-admin

# install GitLab
gem install --conservative charlock_holmes --version '0.6.8'
pip install pygments
gem install --conservative bundler
cd "${gitlabhome}"

# clone GitLab
"${SUDO}" "${gitlabuser}" \
	git clone -b stable https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab

# config GitLab
"${SUDO}" "${gitlabuser}" \
	cp config/gitlab.yml.example config/gitlab.yml

# use SQLite (TODO: ??? really  ???)
"${SUDO}" "${gitlabuser}" \
	cp config/database.yml.sqlite config/database.yml

# install gems for database
"${SUDO}" "${gitlabuser}" \
	bundle install --without development test mysql postgres --deployment

# setup the db
"${SUDO}" "${gitlabuser}" \
	bundle exec rake gitlab:app:setup RAILS_ENV=production

# setup hooks
cp ./lib/hooks/post-receive \
	"${githome}/.gitolite/hooks/common/post-receive"
chown "${gituser}":"${gituser}" \
	"${githome}/.gitolite/hooks/common/post-receive"

# check status
echo "" ; echo "Checking install status ..." ; echo ""
"${SUDO}" "${gitlabuser}" \
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
"${SUDO}" "${gitlabuser}" bundle exec rails s -e production

echo ""
IP_ADDR=$(ifconfig ${ethdev} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }')
echo "Visit: $IP_ADDR:3000 from your browser, and login with:"
echo "admin@local.host	5iveL!fe"
echo ""
echo "NOTE: It will take a while to load the page the first time it is accessed,"
echo "due to compiling times on java-script, jquery core, and css files."
echo ""

# EOF
