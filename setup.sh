#/bin/bash

#Setting up gitolite, gitweb, mantisbt
#create the git user

GIT_USER="git"
GIT_HOME="/home/git"
WEB_DIR="/var/www"
MANTISBT="mantisbt-1.2.19"
MBT_ADMIN="admin@example.com"
MBT_WEBMASTER="wm@example.com"
MBT_REPLY="nr@example.com"
MBT_BOUNCE="bounce@example.com"

CUSER=$( whoami )

#login method to be used for gitweb
#valid options: none, basic
#GITWEB_LOGIN="basic"
GITWEB_LOGIN="none"

#GITWEB_SSL="YES"
GITWEB_SSL="NO"

GIT_TMP=$( pwd )

if [ $1 == "install" ]; then


if id -u "${GIT_USER}" >/dev/null 2>&1; then
        echo "Not creating user ${GIT_USER}; already exists"
else
        echo "Creating git user ${GIT_USER}"
	sudo adduser --disabled-password --home ${GIT_HOME} ${GIT_USER}
fi

if [ ! -d ${GIT_HOME}/bin ]; then
	echo "Making bin directory"
	sudo -u ${GIT_USER} -g ${GIT_USER} mkdir ${GIT_HOME}/bin
fi
if [ ! -d ${GIT_TMP}/gitolite ]; then
	echo "Cloning gitolite repository"
	git clone git://github.com/sitaramc/gitolite ${GIT_TMP}/gitolite 
	sudo rm -r ${GIT_HOME}/gitolite
fi

cd ${GIT_HOME}
if [ ! -d ${GIT_HOME}/gitolite ]; then
	echo "Copying gitolite repository to git user"
	sudo cp -r ${GIT_TMP}/gitolite ${GIT_HOME}/gitolite
	sudo chown -R ${GIT_USER}:${GIT_USER} ${GIT_HOME}/gitolite
	sudo -H -u ${GIT_USER} -g ${GIT_USER} ${GIT_HOME}/gitolite/install -ln ${GIT_HOME}/bin
	sudo ln -s ${GIT_HOME}/bin/gitolite /usr/bin/gitolite
fi

if [ ! -e ${GIT_HOME}/admin.pub ]; then
	echo "Copying admin public key to user ${GIT_USER}"
	sudo cp ~/.ssh/id_rsa.pub ${GIT_HOME}/admin.pub
	sudo chown ${GIT_USER}:${GIT_USER} ${GIT_HOME}/admin.pub
	cd ${GIT_HOME}
	echo "sudo -H -u ${GIT_USER} -g ${GIT_USER} gitolite setup -pk ${GIT_HOME}/admin.pub"
	sudo -H -u ${GIT_USER} -g ${GIT_USER} gitolite setup -pk ${GIT_HOME}/admin.pub
fi

echo "Beginning setup of gitweb"

#only user and group need any access at all to the git user home directory
#sudo chmod -R o-wrx ${GIT_HOME}
sudo chmod g+r ${GIT_HOME}/projects.list
sudo chmod g+rx ${GIT_HOME}/repositories

cd ${GIT_HOME}

if [ ! -d ${GIT_TMP}/git ]; then
	echo "Cloning git repository"
	git clone git://git.kernel.org/pub/scm/git/git.git ${GIT_TMP}/git
	sudo rm -r ${GIT_HOME}/git
fi

if [ ! -d ${GIT_HOME}/git ]; then
	echo "Copying git repository"
	sudo cp -r ${GIT_TMP}/git ${GIT_HOME}/git
	sudo chown -R ${GIT_USER}:${GIT_USER} ${GIT_HOME}/git
fi

GIT_LOCATION=$( which git )
GIT_LOCATION=${GIT_LOCATION%/*}

echo "Editing .gitolite.rc"
sudo sed -i.bak 's/GIT_CONFIG_KEYS                 =>  \x27\x27/GIT_CONFIG_KEYS                 =>  \x27core.sharedRepository\x27/' ${GIT_HOME}/.gitolite.rc

if [ ! -d ${GIT_TMP}/gitolite-admin ]; then
	echo "Cloning gitolite-admin repository"
	git clone git@localhost:gitolite-admin.git ${GIT_TMP}/gitolite-admin
	cd ${GIT_TMP}/gitolite-admin
	sudo sed -i.bak '/repo testing/ a\    config core.sharedRepository = 0640' conf/gitolite.conf
	git add conf/gitolite.conf
	git commit -m "Add sharedRepository setting to testing repository"
	git push origin master
fi

echo "Fixing testing.git permissions"
sudo find ${GIT_HOME}/repositories/testing.git -type f -exec chmod g+r {} \;
sudo find ${GIT_HOME}/repositories/testing.git -type d -exec chmod g+rx {} \;

sudo chmod g+x ${GIT_HOME}/.gitolite
sudo chmod g+rwx ${GIT_HOME}/.gitolite/logs
sudo chmod g+rx ${GIT_HOME}/.gitolite/conf
sudo chmod -R g+r ${GIT_HOME}/.gitolite/conf
sudo chmod -R g+rw ${GIT_HOME}/.gitolite/logs

if [ ! -d ${GIT_TMP}/testing ]; then
	echo "Cloning test repository"
	git clone git@localhost:testing.git ${GIT_TMP}/testing
	cd ${GIT_TMP}/testing
	touch first_file.txt
	git add first_file.txt
	git commit -m "First commit to test repository"
	git push origin master
	echo "Put some data in the file" >> first_file.txt
	git add first_file.txt
	git commit -m "Add some data to the first file"
	git push origin master
fi
cd ~


echo "GIT location: ${GIT_LOCATION}"
cd ${GIT_HOME}/git
sudo -u ${GIT_USER} make \
	bindir=${GIT_LOCATION} \
	GITWEB_LIST=${GIT_HOME}/projects.list \
	GITWEB_PROJECTROOT=${GIT_HOME}/repositories \
	GITWEB_CONFIG_SYSTEM=${GIT_HOME}/gitwebsettings.conf \
	clean gitweb
cd ..
if [ ! -d gitweb ]; then
	sudo -u ${GIT_USER} mkdir gitweb
	sudo -u ${GIT_USER} mkdir gitweb/static
fi
sudo -u ${GIT_USER} mv git/gitweb/gitweb.cgi gitweb/
sudo -u ${GIT_USER} cp -r git/gitweb/static/ gitweb/

if [ ! -e ${GIT_HOME}/gitwebsettings.conf ]; then
	sudo -u ${GIT_USER} touch $GIT_HOME/gitwebsettings.conf
fi

if [ ! -e ${GIT_HOME}/gitweb.conf ]; then
	echo "Making gitweb.conf"
	sudo touch ${GIT_HOME}/gitweb.conf
	sudo chown ${CUSER} ${GIT_HOME}/gitweb.conf
	echo "Alias /gitweb ${GIT_HOME}/gitweb" >> ${GIT_HOME}/gitweb.conf
	echo "" >> ${GIT_HOME}/gitweb.conf
	if [ ${GITWEB_SSL} == "YES" ]; then
	 echo "<Location /gitweb>" >> ${GIT_HOME}/gitweb.conf
	 echo "  SSLRequireSSL" >> ${GIT_HOME}/gitweb.conf
	 echo "</Location>" >> ${GIT_HOME}/gitweb.conf
	 echo "" >> ${GIT_HOME}/gitweb.conf
	 echo "<Location /mantisbt>" >> ${GIT_HOME}/gitweb.conf
	 echo "  SSLRequireSSL" >> ${GIT_HOME}/gitweb.conf
	 echo "</Location>" >> ${GIT_HOME}/gitweb.conf
	 echo "" >> ${GIT_HOME}/gitweb.conf
	fi
	echo "<Directory ${GIT_HOME}/gitweb>" >> ${GIT_HOME}/gitweb.conf
	echo "  Options +FollowSymLinks +ExecCGI" >> ${GIT_HOME}/gitweb.conf
	echo "  AddHandler cgi-script .cgi" >> ${GIT_HOME}/gitweb.conf
	if [ ${GITWEB_LOGIN} == "basic" ]; then
	 sudo rm ${GIT_HOME}/gitweb_pw
	 echo "Creating password for user ${CUSER} on gitweb"
	 sudo htpasswd -c ${GIT_HOME}/gitweb_pw ${CUSER}
	 sudo chown ${GIT_USER}:${GIT_USER} ${GIT_HOME}/gitweb_pw
	 sudo chmod 0640 ${GIT_HOME}/gitweb_pw
	 echo "  AuthType Basic" >> ${GIT_HOME}/gitweb.conf
	 echo "  AuthName \"Authorization required\"" >> ${GIT_HOME}/gitweb.conf
	 echo "  AuthBasicProvider file" >> ${GIT_HOME}/gitweb.conf
	 echo "  AuthUserFile ${GIT_HOME}/gitweb_pw" >> ${GIT_HOME}/gitweb.conf
	 echo "  Require valid-user " >> ${GIT_HOME}/gitweb.conf
	elif [ ${GITWEB_LOGIN} == "none" ]; then
	 echo "No authentication specified for gitweb"
	else
	 echo "ERROR: Invalid gitweb login option specified"
	 sudo rm ${GIT_HOME}/gitweb.conf
	 exit
	fi 
	echo "</Directory>" >> ${GIT_HOME}/gitweb.conf
	echo "" >> ${GIT_HOME}/gitweb.conf
	sudo chown ${GIT_USER} ${GIT_HOME}/gitweb.conf
fi

if [ ! -e /etc/apache2/conf.d/gitweb.conf ]; then
	echo "Copying gitweb stuff to apache2"
	sudo ln -s ${GIT_HOME}/gitweb.conf /etc/apache2/conf.d/gitweb.conf
	sudo ln -s ${GIT_HOME}/gitweb/gitweb.cgi ${GIT_HOME}/gitweb/index.cgi
	sudo a2enmod cgi
	sudo usermod -a -G git www-data
fi

#sudo chmod -R o-wrx ${GIT_HOME}
sudo service apache2 restart

echo "Installing mantisbt"
if [ ! -e ${GIT_TMP}/${MANTISBT}.zip ]; then
	echo "Downloading ${MANTISBT}"
	wget http://sourceforge.net/projects/mantisbt/files/latest/download?source=files -O ${MANTISBT}.zip
	sudo rm -r ${GIT_HOME}/${MANTISBT}
fi

if [ ! -d ${GIT_HOME}/${MANTISBT} ]; then
	echo "Extracting mantisbt"
	sudo unzip ${GIT_TMP}/${MANTISBT}.zip -d ${GIT_HOME} > /dev/null 2>&1
	sudo chown -R ${GIT_USER}:${GIT_USER} ${GIT_HOME}/${MANTISBT}
	sudo chmod -R g+rw ${GIT_HOME}/${MANTISBT}
	sudo chmod g+x ${GIT_HOME}/${MANTISBT}
	sudo ln -s ${GIT_HOME}/${MANTISBT} ${WEB_DIR}/mantisbt
	echo "Point a broweser to the mantisbt part of the webserver and do the configuration"
	read -p "Press any key to continue... " -n1 -s
	echo ""
	sudo cp ${GIT_HOME}/${MANTISBT}/config_inc.php ${GIT_TMP}/config_inc.php
	sudo chown ${CUSER}:${CUSER} ${GIT_TMP}/config_inc.php
	sudo tail -n +43 ${GIT_HOME}/${MANTISBT}/config_inc.php.sample >> ${GIT_TMP}/config_inc.php
	sudo sed -i.bak "s/administrator_email\([^$]*\)administrator@example.com/administrator_email\1${MBT_ADMIN}/g" ${GIT_TMP}/config_inc.php
	sudo sed -i.bak "s/webmaster_email\([^$]*\)webmaster@example.com/webmaster_email\1${MBT_WEBMASTER}/g" ${GIT_TMP}/config_inc.php
	sudo sed -i.bak "s/from_email\([^$]*\)noreply@example.com/from_email\1${MBT_REPLY}/g" ${GIT_TMP}/config_inc.php
	sudo sed -i.bak "s/return_path_email\([^$]*\)admin@example.com/return_path_email\1${MBT_BOUNCE}/g" ${GIT_TMP}/config_inc.php
	sudo cp ${GIT_TMP}/config_inc.php ${GIT_HOME}/${MANTISBT}/config_inc.php
	sudo chown ${GIT_USER}:${GIT_USER} ${GIT_HOME}/${MANTISBT}/config_inc.php
	sudo rm -r ${GIT_HOME}/${MANTISBT}/admin
fi

echo "Installing mantisbt source integration"
if [ ! -d ${GIT_TMP}/source-integration ]; then
	echo "Downloading mantisbt source-integration"
	git clone https://github.com/mantisbt-plugins/source-integration.git ${GIT_TMP}/source-integration
fi

echo "Copying source integration files"
sudo cp -r ${GIT_TMP}/source-integration/Source ${GIT_HOME}/${MANTISBT}/plugins
sudo cp -r ${GIT_TMP}/source-integration/SourceGitweb ${GIT_HOME}/${MANTISBT}/plugins

echo "Login to mantisbt"
echo "Go to Manage Plugins"
echo "Click Install in the row with Source Control Integration"
echo "Click Install in the row with Gitweb Integration"
echo "Click on the Source Control Integration link"
echo "Enter the following line into the API key field"
MANTISBT_API_KEY=$( openssl rand -hex 12 )
echo ${MANTISBT_API_KEY}MANTISBT_API_KEY=$( openssl rand -hex 12 )
echo ${MANTISBT_API_KEY}
MANTISBT_DBLOCATE=$( sudo sed -n "s/.*g_hostname.*=.*\x27\(.*\)\x27.*/\1/p" ${GIT_HOME}/${MANTISBT}/config_inc.php )
MANTISBT_DBTYPE=$( sudo sed -n "s/.*g_db_type.*=.*\x27\(.*\)\x27.*/\1/p" ${GIT_HOME}/${MANTISBT}/config_inc.php )
MANTISBT_DBNAME=$( sudo sed -n "s/.*g_database_name.*=.*\x27\(.*\)\x27.*/\1/p" ${GIT_HOME}/${MANTISBT}/config_inc.php )
MANTISBT_USER=$( sudo sed -n "s/.*g_db_username.*=.*\x27\(.*\)\x27.*/\1/p" ${GIT_HOME}/${MANTISBT}/config_inc.php )
MANTISBT_UPASS=$( sudo sed -n "s/.*g_db_password.*=.*\x27\(.*\)\x27.*/\1/p" ${GIT_HOME}/${MANTISBT}/config_inc.php )
#check for the key in table mantis_config_table
#config_id = plugin_Source_api_key
#value = ${MANTISBT_API_KEY}

#mysql -D bugtracker -N -s -u mantis -pmantis -e "SELECT * FROM mantis_config_table WHERE config_id=\"plugin_Source_api_key\" AND value=\"041fbbcf61f10862cf254faf\";"
MANTISBT_API_KEY_SET=$( mysql -D ${MANTISBT_DBNAME} -N -s -u ${MANTISBT_USER} -p${MANTISBT_UPASS} -e "SELECT * FROM mantis_config_table WHERE config_id=\"plugin_Source_api_key\" AND value=\"${MANTISBT_API_KEY}\";" | wc -l );
while [ $MANTISBT_API_KEY_SET == 0 ]
do
echo "ERROR: API_KEY NOT ENTERED CORRECTLY. PLEASE TRY AGAIN"
echo "Login to mantisbt"
echo "Go to Manage Plugins"
echo "Click Install in the row with Source Control Integration"
echo "Click Install in the row with Gitweb Integration"
echo "Click on the Source Control Integration link"
echo "Enter the following line into the API key field"
MANTISBT_API_KEY=$( openssl rand -hex 12 )
echo ${MANTISBT_API_KEY}
echo "Click Update Configuration"
read -p "Press any key to continue... " -n1 -s
echo ""
MANTISBT_API_KEY_SET=$( mysql -D ${MANTISBT_DBNAME} -N -s -u ${MANTISBT_USER} -p${MANTISBT_UPASS} -e "SELECT * FROM mantis_config_table WHERE config_id=\"plugin_Source_api_key\" AND value=\"${MANTISBT_API_KEY}\";" | wc -l );
done

	
#thsi fi belongs to the end of the install if
fi

if [ $1 == "remove" ]; then

if [ -L ${WEB_DIR}/mantisbt ]; then
	sudo rm ${WEB_DIR}/mantisbt
fi

if [ -L /etc/apache2/conf.d/gitweb.conf ]; then
	echo "Removing gitweb stuff from apache2/conf.d"
	sudo rm /etc/apache2/conf.d/gitweb.conf
	sudo deluser www-data git
fi

if id -u "${GIT_USER}" >/dev/null 2>&1; then
        echo "Removing user ${GIT_USER} and deleting home directory ${GIT_HOME}"
	sudo deluser --remove-home ${GIT_USER}
	sudo delgroup ${GIT_USER}
	sudo rm /usr/bin/gitolite
	rm -rf ${GIT_TMP}/testing
	rm -rf ${GIT_TMP}/gitolite-admin
fi

fi
