#!/bin/bash

function showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./coolpbx.sh

-h,	-help,		--help                  	Display help
-v,	-verbose,	--verbose				Run script in verbose mode. Will print out each step of execution.
-d,	-debug,		--debug					Display debug information.

			--superadmin=XXXX			The initial superadmin, by default is superadmin.
			--superadmin-password=XXXX		The superadmin password, if not specified it will be random.
			--domain-name=XXXX			Initial domain name.
			--database-type=mysql|pgsql		The database type it will be used.
			--database-host=X.X.X.X			The database IP, if not speciied it will be 127.0.0.1.
			--database-port=9999			The port to connect. If not specified, it will be 3309 for mysql or 5432 for pgsql.
			--database-username=XXXX		The database use to use. If it doesn't exist, the script will attempt to create it.
			--database-username-password=XXXX	The database user passwor to connect.
			--database-admin-username=XXXX		The admin database username to use to configure. If not specified it will be root for mysql and postgres for pgsql.
			--database-admin-username-password=XXXX	The admin database username password to use. If not specified, the datbase-username-password value will be used.

			--slave					Just add a slave node. Database must be external.

About:
CoolPBX 1, is a fork that comes from FusionPBX 5. It contains a lot of feautres that have been rejected or removed from the original project. Some of them:
	- MySQL/MariaDB support, FusionPBX 5 has removed it, but since FreeSWITCH 1.10 has now mod_mariadb, it doesn't make sense not having it.
	- Parent-Child domain support, FusionPBX 4.4 rejected a patch that will help business to have a reseller scheme.
	- Billing/LCR ready (comming soon).
	- and more.

CoolPBX 2 (in the future), will drop FusionPBX PHP API in favor of Laravel.

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


function setDefaults() {
	if [ .$superadmin = .'' ]; then
		export superadmin=superadmin
	fi

	if [ .$superadmin_password = .'' ]; then
		export superadmin_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
	fi

	if [ .$domain_name = .'' ]; then
		export domain_name=$(hostname -I | cut -d ' ' -f1)
	fi

	if [ .$database_type = .'' ]; then
		export database_type=mysql
	else
		case "${database_type}" in
			mariadb|mysql)
				_type=mysql
				;;
			postgresql|postgres)
				_type=pgsql
				;;
		esac

		export database_type=${_type}
	fi

	if [ .$database_host = .'' ]; then
		export database_host=127.0.0.1
	fi

	if [ .$database_port = .'' ]; then
		case "${database_type}" in
			mysql)
				_port=3306
				;;
			pgsql)
				_port=5432
				;;
		esac

		export database_port=${_port}
	fi

	if [ .$database_name = .'' ]; then
		export database_name=coolpbx
	fi

	if [ .$database_username = .'' ]; then
		export database_username=coolpbx
	fi

	if [ .$database_username_password = .'' ]; then
		export database_username_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
	fi

	if [ .$database_admin_username = .'' ]; then
		case "${database_type}" in
			mysql)
				_admin=root
				;;
			pgsql)
				_admin=postgres
				;;
		esac
		export database_admin_username=${_admin}
	fi

	if [ .$slave = .'' ]; then
		export slave=0
	fi
}

function is_localhost() {
	_ip=$1
	_result=0

	case "${_ip}" in
		localhost|127.0.0.1|::1|0:0:0:0:0:0:0:1)
			_result=1
			;;
	esac
	echo ${_result}
}

function build_connection_string() {
	_result='';

	case "${database_type}" in
		mysql|mariadb)
			_result="mariadb://Server=${database_host}; Port=${database_port}; Database=${database_name}; Uid=${database_username}; Pwd=${database_username_password}"
			;;
		pgsql)
			_result="pgsql://hostaddr=${database_host} port=${database_port} dbname=${database_name} user=${database_username} password=${database_username_password} options=''"
			;;
	esac
	echo ${_result}
}

function build_freeswitch_connection_string() {
	_result='';

	case "${database_type}" in
		mysql|mariadb)
			_result="mariadb://Server=${database_host}; Port=${database_port}; Database=freeswitch; Uid=${database_username}; Pwd=${database_username_password}"
			;;
		pgsql)
			_result="pgsql://hostaddr=${database_host} port=${database_port} dbname=freeswitch user=${database_username} password=${database_username_password} options=''"
			;;
	esac
	echo ${_result}
}

echo -e "CoolPBX installer (a FusionPBX fork)\n"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "debug,help,verbose,superadmin::,superadmin-password::,domain-name::,database-type::,database-host:,database-port:,database-name::,database-username::,database-username-password::,database-admin-username::,database-admin-username-password::,slave" -o "dhv" -a -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters 
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
	case "$1" in
		-d|--debug)
			set -xv  # Set xtrace and verbose mode.
			;;
		-h|--help)
			showHelp
			exit 0
			;;
		-v|--verbose)
			export verbose=1
			;;
		--superadmin)
			export superadmin=$2
			;;
		--superadmin-password)
			export superadmin_password=$2
			;;
		--domain-name)
			export domain_name=$2
			;;
		--database-type)
			export database_type=$2
			;;
		--database-host)
			export database_host=$2
			;;
		--database-port)
			export database_port=$2
			;;
		--database-name)
			export database_name=$2
			;;
		--database-username)
			export database_username=$2
			;;
		--database-username-password)
			export database_username_password=$2
			;;
		--database-admin-username)
			export database_admin_username=$2
			;;
		--database-admin-username-password)
			export database_admin_username_password=$2
			;;
		--slave)
			export slave=1
			;;
		--)
			shift
			break
			;;
	esac
	shift
done

export original_database_type=${database_type}

if [ .$verbose = .'1' ]; then
	echo 'Prameters received:'
	echo "Super Admin username: ${superadmin}"
	echo "Super Admin password: ${superadmin_password}"
	echo "Default domain: ${domain_name}"
	echo "Database type: ${database_type}"
	echo "Database host: ${database_host}"
	echo "Database port: ${database_port}"
	echo "Database name: ${database_name}"
	echo "Database username: ${database_username}"
	echo "Database username password: ${database_username_password}"
	echo "Database admin username: ${database_admin_username}"
	echo "Database admin username password: ${database_admin_username_password}"
	echo "Slave: ${slave}"
fi

setDefaults

echo 'Configuring CoolPBX with the following parameters:'
echo "Super Admin username: ${superadmin}"
echo "Super Admin password: ${superadmin_password}"
echo "Default domain: ${domain_name}"
echo "Original database type: ${original_database_type}"
echo "Database type: ${database_type}"
echo "Database host: ${database_host}"
echo "Database port: ${database_port}"
echo "Database name: ${database_name}"
echo "Database username: ${database_username}"
echo "Database username password: ${database_username_password}"
echo "Database admin username: ${database_admin_username}"
echo "Database admin username password: ${database_admin_username_password}"
echo "Slave: ${slave}"

# TODO: validate the following
# domain_name resolvable
# port_number numeric
# database_host IPv4/6
# more functions, smaller code

. /etc/os-release

echo -e "\n${NAME} ${VERSION} detected"

MAJOR_VERSION=$(echo ${VERSION}|cut -d '.' -f 1)

echo "Disabling SELinux, you may need to reboot after the installation is done."
setenforce 0
sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config

echo "Installing the repositories and base packages..."
yum -y update --enablerepo=* --disablerepo=okay-debuginfo,media-* --nogpg
yum -y install epel-release  --enablerepo=* --disablerepo=okay-debuginfo,media-* --nogpg
yum -y install https://rpms.remirepo.net/enterprise/remi-release-${MAJOR_VERSION}.rpm  --enablerepo=* --disablerepo=okay-debuginfo,media-* --nogpg
yum -y install http://repo.okay.com.mx/centos/${MAJOR_VERSION}/x86_64/release/okay-release-1-6.el${MAJOR_VERSION}.noarch.rpm  --enablerepo=* --disablerepo=okay-debuginfo,media-* --nogpg
yum -y install git task-fusionpbx task-fusionpbx-${database_type}  mod_ssl fail2ban-systemd freeswitch-fail2ban-rules fusionpbx-fail2ban-rules --enablerepo=* --disablerepo=okay-debuginfo,media-* --nogpg

echo "Configuring Apache directory..."
sed -i 's/\/var\/www\/html/\/var\/www\/CoolPBX/' /etc/httpd/conf/httpd.conf
sed -i '0,/AllowOverride None/{s/AllowOverride None/AllowOverride All/}' /etc/httpd/conf/httpd.conf

echo "Creating Cache directory..."
mkdir -p /var/cache/fusionpbx
chown -R freeswitch:daemon /var/cache/fusionpbx

if [ ! -d "/var/www/CoolPBX" ]; then
	echo "Downloading CoolPBX..."
	git clone https://github.com/OKayInc/CoolPBX.git /var/www/CoolPBX
else
	echo "Looks like CoolPBX was already installing, updating"
	pushd /var/www/CoolPBX
	git pull
	popd
fi

echo "Copying configuration into FreeSWITCH..."
if [ ! -f "/etc/freeswitch.tar.gz" ]; then
	echo "Backing up your configuration"
	if [ .$verbose = .'1' ]; then
		_taropt='-czvf'
	else
		_taropt='-czf'
	fi
	tar ${_taropt} /etc/freeswitch.tar.gz /etc/freeswitch
fi

rm -rf /etc/freeswitch
mkdir -p /etc/freeswitch

echo "Configuring CoolPBX..."
mkdir -p /etc/fusionpbx

if [ .$verbose = .'1' ]; then
	_cpopt='-Rvf'
	_chopt='-Rvf'
else
	_cpopt='-Rf'
	_chopt='-Rf'
fi
cp ${_cpopt} /var/www/CoolPBX/resources/templates/conf/* /etc/freeswitch

chown ${_chopt} freeswitch:daemon /etc/freeswitch
chown ${_chopt} freeswitch:daemon /var/lib/freeswitch
chown ${_chopt} freeswitch:daemon /usr/share/freeswitch
chown ${_chopt} freeswitch:daemon /var/log/freeswitch
chown ${_chopt} freeswitch:daemon /var/run/freeswitch

/bin/find  /etc/freeswitch -type d -exec chmod 2770 {} \;
/bin/find  /etc/freeswitch -type f -exec chmod 0664 {} \;

cat <<'EOF' > /etc/fusionpbx/config.php
<?php
        //set the database type
                $db_type = '{database_type}'; //sqlite, mysql, pgsql, others with a manually created PDO connection

                $db_host = '{database_host}';
                $db_port = '{database_port}';
                $db_name = '{database_name}';
                $db_username = '{database_username}';
                $db_password = '{database_password}';

        //show errors
                ini_set('display_errors', '1');
                //error_reporting (E_ALL); // Report everything
                //error_reporting (E_ALL ^ E_NOTICE); // Report everything
                error_reporting(E_ALL ^ E_NOTICE ^ E_WARNING ); //hide notices and warnings
EOF


cat <<'EOF' > /etc/fusionpbx/config.conf
#database system settings
database.0.type = {database_type}
database.0.host = {database_host}
database.0.port = {database_port}
database.0.sslmode = prefer
database.0.name = {database_name}
database.0.username = {database_username}
database.0.password = {database_password}

#database switch settings
database.1.type = {database_type}
database.1.host = {database_host}
database.1.port = {database_port}
database.1.sslmode = prefer
database.1.name = freeswitch
database.1.username = {database_username}
database.1.password = {database_password}

#general settings
document.root = /var/www/CoolPBX
project.path =
temp.dir = /tmp
php.dir = /usr/bin
php.bin = php

#cache settings
cache.method = file
cache.location = /var/cache/fusionpbx
cache.settings = true

#switch settings
switch.conf.dir = /etc/freeswitch
switch.sounds.dir = /usr/share/freeswitch/sounds
switch.database.dir = /var/lib/freeswitch/db
switch.recordings.dir = /var/lib/freeswitch/recordings
switch.storage.dir = /var/lib/freeswitch/storage
switch.voicemail.dir = /var/lib/freeswitch/storage/voicemail
switch.scripts.dir = /usr/share/freeswitch/scripts

#switch xml handler
xml_handler.fs_path = false
xml_handler.reg_as_number_alias = false
xml_handler.number_as_presence_id = true

#error reporting hide show all errors except notices and warnings
error.reporting = 'E_ALL ^ E_NOTICE ^ E_WARNING'
EOF

case "${database_type}" in
	mysql|mariadb)
		cat <<'EOF' > /etc/odbc.ini
[freeswitch]
Driver   = MariaDB
SERVER   = {database_host}
PORT     = {database_port}
DATABASE = freeswitch
OPTION  = 67108864
;Socket   = /var/lib/mysql/mysql.sock
threading=0
MaxLongVarcharSize=65536

[fusionpbx]
Driver   = MariaDB
SERVER   = {database_host}
PORT     = {database_port}
DATABASE = {database_name}
OPTION  = 67108864
Socket   = /var/lib/mysql/mysql.sock
threading=0
EOF
		;;
	pgsql)
		cat <<'EOF' > /etc/odbc.ini
EOF
		;;
esac

sed -i /etc/fusionpbx/config.php -e s:"{database_type}:${database_type}:"
sed -i /etc/fusionpbx/config.php -e s:"{database_host}:${database_host}:"
sed -i /etc/fusionpbx/config.php -e s:"{database_port}:${database_port}:"
sed -i /etc/fusionpbx/config.php -e s:"{database_name}:${database_name}:"
sed -i /etc/fusionpbx/config.php -e s:"{database_username}:${database_username}:"
sed -i /etc/fusionpbx/config.php -e s:"{database_password}:${database_username_password}:"

sed -i /etc/fusionpbx/config.conf -e s:"{database_type}:${database_type}:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_host}:${database_host}:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_port}:${database_port}:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_name}:${database_name}:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_username}:${database_username}:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_password}:${database_username_password}:"

sed -i /etc/odbc.ini -e s:"{database_host}:${database_host}:"
sed -i /etc/odbc.ini -e s:"{database_port}:${database_port}:"
sed -i /etc/odbc.ini -e s:"{database_name}:${database_name}:"

_is_local_db=$(is_localhost ${database_host})

case "${database_type}" in
	mysql|mariadb)
		if [ .$_is_local_db = '.1' ]; then
			if [ .$slave = .'1' ]; then
				echo '--slave flag can not be used if you are using a local database'
				exit 1
			else
				if [ .$verbose = .'1' ]; then
					echo 'Restarting local database daemon'
				fi

				case "${MAJOR_VERSION}" in
					7)
						db_service=mysql
						;;
					8|9)
						db_service=mariadb
						;;
				esac

				systemctl enable ${db_service}
				systemctl start ${db_service}
			fi
		fi

		if [ .$slave = .'1' ]; then
			echo "Let's not destroy the database"
		else
			echo "Creating MariaDB/MySQL database if it doesn't exist..."
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="CREATE DATABASE IF NOT EXISTS ${database_name}"
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="CREATE DATABASE IF NOT EXISTS freeswitch"
		fi

		echo "Adding MariaDB/MySQL user permissions..."
		for ip in $(hostname -I)
		do
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="GRANT ALL PRIVILEGES ON freeswitch.* TO '${database_username}'@'${ip}' IDENTIFIED BY '${database_username_password}'"
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_username}'@'${ip}' IDENTIFIED BY '${database_username_password}'"
		done
		;;
	pgsql)
		if [ .$_is_local_db = '.1' ]; then
			if [ .$slave = .'1' ]; then
				echo '--slave flag can not be used if you are using a local database'
				exit 1
			else
				if [ .$verbose = .'1' ]; then
					echo 'Restarting local database daemon'
				fi

				systemctl enable postgresql
				systemctl start postgresql
			fi
		fi

		if [ .$slave = .'1' ]; then
			echo "Let's not destroy the database"
		else
			echo "Droppig PostgreSQL database..."
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c 'DROP SCHEMA public cascade;'
			echo "Creating PostgreSQL database..."
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c 'CREATE SCHEMA public;'
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "CREATE DATABASE ${database_name};"
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "CREATE DATABASE freeswitch;"
			echo "Adding PostgreSQL roles..."
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "CREATE ROLE ${database_username} WITH SUPERUSER LOGIN PASSWORD '${database_username_password}';"
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '${database_username_password}';"
			echo "Adding PostgreSQL user permissions..."
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "GRANT ALL PRIVILEGES ON DATABASE ${database_name} to ${database_username};"
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to ${database_username};"
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch;"
		fi
		;;
esac

if [ .$verbose = .'1' ]; then
	shopt='> /dev/null 2>&1'
else
	shopt=''
fi

echo "Setting up CoolPBX..."
pushd /var/www/CoolPBX
	php /var/www/CoolPBX/core/upgrade/upgrade_schema.php ${shopt}
	domain_uuid=$(uuidgen)
	sql_domain="INSERT INTO v_domains (domain_uuid, domain_name, domain_enabled) values('${domain_uuid}', '${domain_name}', 'true');"

	case "${database_type}" in
		mysql|mariadb)
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="${sql_domain}" ${database_name}
			;;
		pgsql)
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "${sql_domain}"
			;;
	esac

	default_setting_uuid=$(uuidgen)
	sql_switch_conf="INSERT INTO v_default_settings (default_setting_uuid, app_uuid, default_setting_category, default_setting_subcategory, default_setting_name, default_setting_value, default_setting_order, default_setting_enabled, default_setting_description) VALUES('${default_setting_uuid}', NULL, 'switch', 'conf', 'dir', '/etc/freeswitch', NULL, 'true', NULL);"
	case "${database_type}" in
		mysql|mariadb)
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="${sql_switch_conf}" ${database_name}
			;;
		pgsql)
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "${sql_switch_conf}"
			;;
	esac

	default_setting_uuid=$(uuidgen)
	sql_switch_conf="INSERT INTO v_default_settings (default_setting_uuid, app_uuid, default_setting_category, default_setting_subcategory, default_setting_name, default_setting_value, default_setting_order, default_setting_enabled, default_setting_description) VALUES('${default_setting_uuid}', NULL, 'switch', 'languages', 'dir', '/etc/freeswitch/languages', NULL, 'true', NULL);"
	case "${database_type}" in
		mysql|mariadb)
			mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="${sql_switch_conf}" ${database_name}
			;;
		pgsql)
			PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "${sql_switch_conf}"
			;;
	esac

	php /var/www/CoolPBX/core/upgrade/upgrade_domains.php
popd

user_uuid=$(uuidgen)
user_salt=$(uuidgen)
password_hash=$(echo -n ${user_salt}${superadmin_password}|md5sum -t | cut -d' ' -f 1)

sql_useradmin="INSERT INTO v_users (user_uuid, domain_uuid, username, password, salt, user_enabled) values('${user_uuid}', '${domain_uuid}', '${superadmin}', '${password_hash}', '${user_salt}', 'true');"

case "${database_type}" in
	mysql|mariadb)
		mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="${sql_useradmin}" ${database_name}
		;;
	pgsql)
		PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "${sql_useradmin}"
		;;
esac

sql_superadmin_group="SELECT group_uuid FROM v_groups WHERE group_name = 'superadmin';"
case "${database_type}" in
	mysql|mariadb)
		group_uuid=$(mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} -s -N --execute="${sql_superadmin_group}" ${database_name})
		;;
	pgsql)
		group_uuid=$(PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -t -c "${sql_superadmin_group}")
		;;
esac

group_uuid=$(echo $group_uuid | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
user_group_uuid=$(uuidgen)
group_name=superadmin
sql_user_groups="INSERT INTO v_user_groups (user_group_uuid, domain_uuid, group_name, group_uuid, user_uuid) VALUES('${user_group_uuid}', '${domain_uuid}', '${group_name}', '${group_uuid}', '${user_uuid}');"

case "${database_type}" in
	mysql|mariadb)
		mysql --host=${database_host} --port=${database_port} --user=${database_admin_username} --password=${database_admin_username_password} --execute="${sql_user_groups}" ${database_name}
		;;
	pgsql)
		PGPASSWORD="${database_admin_username_password}" psql --host=${database_host} --port=${database_port}  --username=${database_admin_username} -c "${sql_user_groups}"
		;;
esac

_dsn=$(build_freeswitch_connection_string)
sed -i /etc/freeswitch/vars.xml -e s"|{dsn}|${_dsn}|"
case "${database_type}" in
	mysql|mariadb)
		sed -i /etc/freeswitch/vars.xml -e s"|{odbc-dsn}|freeswitch:${database_username}:${database_username_password}|"
		;;
	pgsql)
		sed -i /etc/freeswitch/vars.xml -e s"|{odbc-dsn}|${_dsn}|"
		;;
esac
xml_cdr_username=$(dd if=/dev/urandom bs=1 count=12 2>/dev/null | base64 | sed 's/[=\+//]//g')
xml_cdr_password=$(dd if=/dev/urandom bs=1 count=12 2>/dev/null | base64 | sed 's/[=\+//]//g')
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_http_protocol}:http:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{domain_name}:127.0.0.1:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_project_path}::"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_user}:$xml_cdr_username:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_pass}:$xml_cdr_password:"

pushd /var/www/CoolPBX
	php /var/www/CoolPBX/core/upgrade/upgrade_schema.php ${shopt}
popd

rm -f /var/lib/php/session/*

echo "Configuring Crontabs..."
cat << EOF > /etc/cron.hourly/coolpbx-fs
#!/bin/bash
cd /var/www/CoolPBX && /usr/bin/php pull_vars_xml.php && /usr/bin/fs_cli -x 'reloadxml'
/bin/chown freeswitch:daemon /var/lib/freeswitch/{recordings,storage} /usr/share/freeswitch/sounds/ /etc/freeswitch -Rf
/bin/find  /var/lib/freeswitch/{recordings,storage} /usr/share/freeswitch/sounds/ /etc/freeswitch -type d -exec chmod 2770 {} \;
/bin/find  /var/lib/freeswitch/{recordings,storage} /usr/share/freeswitch/sounds/ /etc/freeswitch -type f -exec chmod 0664 {} \;
EOF
chmod +x /etc/cron.hourly/coolpbx-fs

echo "Configuring Fail2ban..."
cat /usr/share/doc/fusionpbx-fail2ban-rules/README.fusionpbx-fail2ban-rules.txt /usr/share/doc/freeswitch-fail2ban-rules/README.freeswitch-fail2ban-rules.txt > /etc/fail2ban/jail.local

echo "Enabling services by default..."
systemctl enable httpd
systemctl enable php-fpm
systemctl enable memcached
systemctl enable freeswitch
systemctl enable fail2ban

echo "Restarting services..."
systemctl restart httpd
systemctl restart php-fpm
systemctl restart memcached
systemctl restart freeswitch
systemctl restart fail2ban

cat << EOF
Your CoolPBX is installed, please take note of the following:

- to access the web interface
EOF
for ip in $(hostname -I)
do
	echo "	http://${ip}"
done
cat << EOF
- to configure HTTPS, type
	edit /etc/httpd/conf.d/ssl.conf to fit your needs (for example, configure a custom certificate), by default, you will have a self-signed certificate.

Need private commercial support? Book it! https://okay.appointlet.com/
Free, public support in the Telegram group at https://t.me/fpbxsupport

Happy VoIP!
EOF
