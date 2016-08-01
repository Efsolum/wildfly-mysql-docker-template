#!/usr/bin/env bash
set -e

PROJECT_NAME='project'

ALPINE_VERSION='3.4'

NODE_VERSION='6.2.0'

JAVA_MINOR_VERSION='8'
JAVA_VERSION="1.${JAVA_MINOR_VERSION}"

MAVEN_MAJOR_VERSION='3'
MAVEN_VERSION="${MAVEN_MAJOR_VERSION}.3.9"

WILDFLY_RELEASE='Final'
WILDFLY_VERSION='10.0.0'
WILDFLY_FULL_VERSION="${WILDFLY_VERSION}.${WILDFLY_RELEASE}"
WILDFLY_SHA256="e00c4e4852add7ac09693e7600c91be40fa5f2791d0b232e768c00b2cb20a84b"

MYSQL_MAJOR_VERSION=5.7

echo "==========> Building MySQL Image"
./mysql-build.bash

echo "==========> Building Wildfly Image"
./wildfly-build.bash

echo "==========> Building Java Image"
./java-build.bash

echo "==========> Building NodeJS Image"
./nodejs-build.bash
