#!/bin/sh
#############################################################
##
##	The standard sh shell is used
##	(dash on ubuntu) because it's
##	the closest to a posix-compliant
##	shell that ships with ubuntu
##	by default. 
##
#############################################################

#############################################################
##
##	CONFIGURATION OPTIONS
##
#############################################################

REQUIRED_PACKAGES="git git-core gcc libxml2-dev libxslt-dev sqlite3 libsqlite3-dev \
	libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev make build-essential \
	zlib1g-dev libicu-dev redis-server openssh-server python-dev python-pip libyaml-dev \
	postfix ruby1.9.3"
	
CHUSR="sudo -H -u"

ETH_ADAPTER="eth1"

#############################################################
##
##	MAIN
##
#############################################################

#----------- Ensure Root Access -----------

if [ "$(id -u)" != "0" ];
then
	echo "Must be run as root. Exiting." 
	exit 1
fi

#----------- Install Prerequisites -----------

apt-get install -y $REQUIRED_PACKAGES

#----------- Add users -----------

adduser --system --shell /bin/sh --gecos 'git user' --group \
	--disabled-password --home /home/git git
	
adduser --disabled-login --gecos 'gitlab system user' gitlab

#----------- Add users to eachother's groups -----------

usermod -a -G git gitlab
usermod -a -G gitlab git

#----------- Generate RSA key ------------

$CHUSR gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
chmod 0444 /home/git/gitlab.pub

#----------- Install and configure Gitolite -----------

# NOTE: This uses the fork of gitolite tweaked for GitLab

cd /home/git

$CHUSR git mkdir bin
$CHUSR git git clone -b gl-v304 https://github.com/gitlabhq/gitolite.git gitolite-src
$CHUSR git sh -c 'echo "PATH=\$PATH:/home/git/bin" >> /home/git/.profile'
$CHUSR git sh -c 'echo "export PATH" >> /home/git/.profile'
$CHUSR git gitolite-src/install -ln /home/git/bin
$CHUSR git sh -c 'PATH=/home/git/bin:$PATH; gitolite setup -pk /home/git/gitlab.pub'

chmod -R g+rwX /home/git/repositories/
chown -R git:git /home/git/repositories/

#----------- Test the Install -------------

$CHUSR gitlab git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
rm -rf /tmp/gitolite-admin

#----------- Install GitLab --------------

gem install --conservative charlock_holmes --version '0.6.8'
pip install pygments
gem install --conservative bundler
cd /home/gitlab

$CHUSR gitlab git clone -b stable https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab

$CHUSR gitlab cp config/gitlab.yml.example config/gitlab.yml

#--- Using SQLite

$CHUSR gitlab cp config/database.yml.sqlite config/database.yml

#--- Install gems for database 

$CHUSR gitlab bundle install --without development test mysql postgres --deployment

#--- Setup database

$CHUSR gitlab bundle exec rake gitlab:app:setup RAILS_ENV=production

#--- Setup hooks

cp ./lib/hooks/post-receive /home/git/.gitolite/hooks/common/post-receive
chown git:git /home/git/.gitolite/hooks/common/post-receive

#--- Check status

echo ""
echo "CHECKING INSTALL STATUS..."
echo ""

$CHUSR gitlab bundle exec rake gitlab:app:status RAILS_ENV=production

echo ""
echo "WERE ALL ANSWERS ABOVE = YES ?"
echo ""

read ANSWER
echo "Answer: $ANSWER"
if [ "$ANSWER" != "yes" ];
then
	echo "Received answer other than 'yes'. Exiting"
	exit 1
fi

echo ""
echo "Succeeded."
echo "Testing the installation..."

#------------ Test GitLab ------------

cd /home/gitlab/gitlab
$CHUSR gitlab bundle exec rails s -e production

echo ""
IP_ADDR=$(ifconfig $ETH_ADAPTER | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo "Visit: $IP_ADDR:3000 from your browser, and login with:"
echo "admin@local.host	5iveL!fe"
echo ""
echo "NOTE: It will take a while to load the page the first time it is accessed, due to compiling times on java-script, jquery core, and css files."
echo ""









