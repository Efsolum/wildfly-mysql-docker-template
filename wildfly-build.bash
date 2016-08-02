#!/usr/bin/env bash
set -e

[ -f './project.bash' ] && source './project.bash'

PROJECT_NAME=${PROJECT_NAME:-'project'}

ALPINE_VERSION=${ALPINE_VERSION:-'3.4'}

JAVA_MINOR_VERSION=${JAVA_MINOR_VERSION:-'8'}
JAVA_VERSION=${JAVA_VERSION:-"1.${JAVA_MINOR_VERSION}"}

WILDFLY_RELEASE=${WILDFLY_RELEASE:-'Final'}
WILDFLY_VERSION=${WILDFLY_VERSION:-'10.0.0'}
WILDFLY_FULL_VERSION=${WILDFLY_FULL_VERSION:-"${WILDFLY_VERSION}.${WILDFLY_RELEASE}"}
WILDFLY_SHA256=${WILDFLY_SHA256:-"e00c4e4852add7ac09693e7600c91be40fa5f2791d0b232e768c00b2cb20a84b"}

CONTAINER_USER=${CONTAINER_USER:-developer}
TEMP_DIR=$(mktemp --directory wildfly-build-XXXXXXXX)

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
ENV JBOSS_HOME /usr/local/wildfly-${WILDFLY_VERSION}
ENV PATH "\${JBOSS_HOME}/bin:\${JAVA_HOME}/bin:\$PATH"

RUN adduser -u $(id -u $USER) -Ds /bin/bash $CONTAINER_USER

COPY apk-install.sh /usr/local/bin/apk-install.sh
RUN chmod u+x /usr/local/bin/apk-install.sh
RUN apk-install.sh

RUN which java && java -version
RUN which javac && javac -version

COPY wildfly-build.bash /usr/local/bin/wildfly-build.bash
RUN chmod u+x /usr/local/bin/wildfly-build.bash
RUN wildfly-build.bash
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} \${JBOSS_HOME}

RUN which domain.sh && domain.sh --version

USER $CONTAINER_USER
WORKDIR /home/$CONTAINER_USER

# 9990 (administration), 8080 (HTTP listener), 8443 (HTTPS listener), 9009 (JPDA debug port)
EXPOSE 9990 8080 8443 9009
CMD sh -c 'kill -STOP \$$'
EOF

cat <<EOF >> ${TEMP_DIR}/apk-install.sh
#!/usr/bin/env sh
set -eo pipefail

apk update
apk add \
			bash \
			ca-certificates \
			expect \
			git \
			openjdk${JAVA_MINOR_VERSION} \
			openjdk${JAVA_MINOR_VERSION}-jre \
			openssl \
			python \
			sudo \
			wget \
		&& echo 'End of package(s) installation.'

echo 'Cleaning up apks'
rm -rf '/var/cache/apk/*'
EOF

cat <<EOF >> $TEMP_DIR/wildfly-build.bash
#!/usr/bin/env bash
set -eo pipefail

mkdir -v /tmp/wildfly-build
cd /tmp/wildfly-build

wget "http://download.jboss.org/wildfly/${WILDFLY_FULL_VERSION}/wildfly-${WILDFLY_FULL_VERSION}.tar.gz"
sha256sum "wildfly-${WILDFLY_FULL_VERSION}.tar.gz" | grep "${WILDFLY_SHA256}"

tar -xvzf wildfly-${WILDFLY_FULL_VERSION}.tar.gz
mv -v wildfly-${WILDFLY_FULL_VERSION} \${JBOSS_HOME}

cd /
rm -vr /tmp/wildfly-build

chmod +x \${JBOSS_HOME}/bin/*
EOF

docker build \
			 --no-cache=false \
			 --tag "${PROJECT_NAME}/wildfly-${JAVA_VERSION}-${WILDFLY_VERSION}:latest" \
			 $TEMP_DIR
docker tag \
			 "${PROJECT_NAME}/wildfly-${JAVA_VERSION}-${WILDFLY_VERSION}:latest" \
			 "${PROJECT_NAME}/wildfly-${JAVA_VERSION}-${WILDFLY_VERSION}:$(date +%s)"
