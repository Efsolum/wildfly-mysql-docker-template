#!/usr/bin/env bash
set -e

[ -f './project.bash' ] && source './project.bash'

PROJECT_NAME=${PROJECT_NAME:-'project'}

JAVA_MINOR_VERSION=${JAVA_MINOR_VERSION:-8}
JAVA_VERSION=${JAVA_VERSION:-"1.${JAVA_MINOR_VERSION}"}
NODE_VERSION=${NODE_VERSION:-'6.2.0'}
WILDFLY_RELEASE='Final'
WILDFLY_VERSION='10.0.0'
WILDFLY_FULL_VERSION="${WILDFLY_VERSION}.${WILDFLY_RELEASE}"
DATABASE_USER=${DATABASE_USER:-'app'}
DATABASE_PASS=${DATABASE_PASS:-'password'}

docker_err() {
		exit=$?

		echo '/nStoping containers'
		docker stop mysql-dbms java-dev node-assets glassfish-web

		exit $exit;
}

trap docker_err ERR

docker run \
			 --detach=true \
			 --name='mysql-dbms' \
			 --env="DATABASE_USER=${DATABASE_USER}" \
			 --env="DATABASE_PASS=${DATABASE_PASS}" \
			 "${PROJECT_NAME}/mysql-dbms:latest"

docker run \
			 --detach=true \
			 --name='java-dev' \
			 --volume="$(dirname $(pwd))/src:/var/www/projects" \
			 --publish='7070:8080' \
			 "${PROJECT_NAME}/java-${JAVA_VERSION}:latest"

docker run \
			 --detach=true \
			 --name='node-assets' \
			 --volume="$(dirname $(pwd))/src:/var/www/projects" \
			 "${PROJECT_NAME}/node-${NODE_VERSION}:latest"

# 9990 (administration), 8080 (HTTP listener), 8181 (HTTPS listener), 9009 (JPDA debug port)
docker run \
			 --detach=true \
			 --name='wildfly-web' \
			 --publish='8080:8080' \
			 --publish='8443:8443' \
			 --publish='9009:9009' \
			 --publish='9990:9990' \
			 "${PROJECT_NAME}/wildfly-${JAVA_VERSION}-${WILDFLY_VERSION}:latest"
