#!/usr/bin/env bash
set -e

[ -f './project.bash' ] && source './project.bash'

PROJECT_NAME=${PROJECT_NAME:-'project'}

ALPINE_VERSION=${ALPINE_VERSION:-'3.4'}

JAVA_MINOR_VERSION=${JAVA_MINOR_VERSION:-'8'}
JAVA_VERSION=${JAVA_VERSION:-"1.${JAVA_MINOR_VERSION}"}

MAVEN_MAJOR_VERSION=${MAVEN_MAJOR_VERSION:-'3'}
MAVEN_VERSION=${MAVEN_VERSION:-"${MAVEN_MAJOR_VERSION}.3.9"}

CONTAINER_USER=${CONTAINER_USER:-developer}
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
ENV SSL_CERT_DIR /etc/ssl/certs
ENV JAVA_HOME /usr/lib/jvm/java-1.${JAVA_MINOR_VERSION}-openjdk
ENV MAVEN_HOME /usr/local/maven-${MAVEN_VERSION}
ENV PATH "\${MAVEN_HOME}/bin:\${JAVA_HOME}/bin:\$PATH"

RUN adduser -u $(id -u $USER) -Ds /bin/bash $CONTAINER_USER

COPY apk-install.sh /usr/local/bin/apk-install.sh
RUN chmod u+x /usr/local/bin/apk-install.sh
RUN apk-install.sh

RUN which java && java -version
RUN which javac && javac -version
RUN which jdb && jdb -version

COPY maven-build.bash /usr/local/bin/maven-build.bash
RUN chmod u+x /usr/local/bin/maven-build.bash
RUN maven-build.bash
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} \${MAVEN_HOME}

RUN which mvn && mvn -version

USER $CONTAINER_USER
WORKDIR /var/www/projects

VOLUME ["/var/www/projects"]
# 8080 (jetty)

EXPOSE 8080
CMD sh -c 'kill -STOP \$$'
EOF

cat <<EOF >> ${TEMP_DIR}/apk-install.sh
#!/usr/bin/env sh
set -eo pipefail

apk update
apk add \
			bash \
			expect \
			ca-certificates \
			git \
			openjdk${JAVA_MINOR_VERSION} \
			openjdk${JAVA_MINOR_VERSION}-jre \
			openssl \
			sudo \
			wget \
		&& echo 'End of package(s) installation.'

echo 'Cleaning up apks'
rm -rf '/var/cache/apk/*'
EOF

cat <<EOF >> $TEMP_DIR/maven-build.bash
#!/usr/bin/env bash
set -eo pipefail

mkdir -v /tmp/maven-build
cd /tmp/maven-build

wget "http://apache.osuosl.org/maven/maven-${MAVEN_MAJOR_VERSION}/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

tar -xvf apache-maven-${MAVEN_VERSION}-bin.tar.gz
mv apache-maven-${MAVEN_VERSION} \${MAVEN_HOME}

rm -rv /tmp/maven-build

cd /
which mvn
mvn --version
EOF

docker build \
			 --no-cache=false \
			 --tag "${PROJECT_NAME}/java-${JAVA_VERSION}:latest" \
			 $TEMP_DIR
docker tag \
			 "${PROJECT_NAME}/java-${JAVA_VERSION}:latest" \
			 "${PROJECT_NAME}/java-${JAVA_VERSION}:$(date +%s)"
