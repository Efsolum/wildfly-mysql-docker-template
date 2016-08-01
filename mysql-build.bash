#!/usr/bin/env bash
set -e

[ -f './project.bash' ] && source './project.bash'

PROJECT_NAME=${PROJECT_NAME:-'project'}

ALPINE_VERSION=${ALPINE_VERSION:-'3.4'}
MYSQL_MAJOR_VERSION=${MYSQL_MAJOR_VERSION:-'5.7'}

DATABASE_USER=${DATABASE_USER:-'app'}
DATABASE_PASS=${DATABASE_PASS:-'password'}

TEMP_DIR=$(mktemp --directory glassfish-build-XXXXXXXX)

docker_end() {
		exit=$?

		echo 'Cleaning up'
		rm -r $TEMP_DIR

		exit $exit;
}

trap docker_end EXIT SIGINT SIGTERM

cat <<EOF > $TEMP_DIR/Dockerfile
FROM alpine:${ALPINE_VERSION}
MAINTAINER 'Matthew Jordan <matthewjordandevops@yandex.com>'

ENV LANG en_US.UTF-8

COPY apk-install.sh /usr/local/bin/apk-install.sh
RUN chmod u+x /usr/local/bin/apk-install.sh
RUN apk-install.sh

COPY my.cnf /etc/mysql/my.cnf

RUN mysql_install_db

COPY mysql_startup.sh /usr/local/bin/mysql_startup.sh
RUN chmod ugo+x /usr/local/bin/mysql_startup.sh

# USER mysql
VOLUME ["/var/lib/mysql"]
EXPOSE 3306

CMD ["mysql_startup.sh"]
EOF

cat <<EOF >> ${TEMP_DIR}/apk-install.sh
#!/usr/bin/env sh
set -eo pipefail

apk update
apk add \
			bash \
			ca-certificates \
			git \
			mysql \
			mysql-client \
		&& echo 'End of package list'

echo 'Cleaning up apks'
rm -rf '/var/cache/apk/*'
EOF


cat <<EOF > $TEMP_DIR/my.cnf
[mysqld]
user = mysql
port = 3306
datadir = /var/lib/mysql
log-bin = /var/lib/mysql/mysql-bin
EOF

cat <<EOF > $TEMP_DIR/mysql_startup.sh
#!/usr/bin/env bash
set -eo pipefail

if [[ ! -f '/run/mysqld/mysql.initialized' ]]; then
echo "Temporarily starting MySQL daemon"
mysqld_safe &
# mysqld_safe --skip-grant-tables --skip-syslog --skip-networking &

echo "Sleeping for a bit"
sleep 10

echo "Executing MySQL DBMS configuration changes."
# mysql \
# 			--verbose \
# 			--execute "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';"
mysql \
			--verbose \
			--execute "CREATE USER '\${DATABASE_USER}'@'localhost' IDENTIFIED BY '\${DATABASE_PASS}';"
mysql \
			--verbose \
			--execute "GRANT ALL ON *.* TO 'app'@'%' IDENTIFIED BY 'password';"
mysql \
			--verbose \
			--execute "GRANT ALL PRIVILEGES ON * . * TO 'app'@'localhost';"
mysql \
			--verbose \
			--execute "flush privileges;"

echo "Stopping MySQL daemon"
mysqladmin shutdown

touch /run/mysqld/mysql.initialized
fi

echo "Starting MySQL daemon"
mysqld --user=mysql

echo "MySQL daemon Shutton Down, bye"
EOF

docker build \
			 --no-cache=false \
			 --tag="${PROJECT_NAME}/mysql-dbms:latest" $TEMP_DIR
docker tag \
			 "${PROJECT_NAME}/mysql-dbms:latest" "project/mysql-dbms:$(date +%s)"
