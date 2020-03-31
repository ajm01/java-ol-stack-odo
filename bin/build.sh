#!/bin/sh

# set -e -o pipefail

date
echo Started StandAlone Version- Full build

if [ "$TEST_ENV" = "true" ]; then
    echo "Running in test mode"
else
    echo "Running in development mode"
fi

if [ ! -f pom.xml ]; then
    echo "The current working directory ($PWD) does not contain a maven project"
    exit 1
fi

/opt/ol/wlp/bin/server stop

echo AJM Project contents:
ls -la

echo AJM - building the pom now...

mvn -B clean package -Dmaven.repo.local=/home/user/.m2/repository -DskipTests=true liberty:create
#mvn -Dmaven.repo.local=/home/user/.m2/repository pre-integration-test liberty:dev
#mvn -Ddebug=false -Dmaven.repo.local=/home/user/.m2/repository pre-integration-test liberty:install-server
if [ ! $? -eq 0 ]; then
    echo "The maven build failed"
    exit 1
fi

date

echo Target directory contents after maven build:
ls -la ./target

date
echo Copying server configuration artifacts to /config
CONFIGDIR=$(dirname $(find /projects/myapp/target/liberty/wlp/usr/servers -name server.xml))
if [ ! $? -eq 0 ]; then
    echo "Cannot start the server because the config directory could not be found"
    exit 1
fi
rm -rf /config/*
cp -r $CONFIGDIR/* /config/
cp -r resources /opt/ol/wlp/output/defaultServer
ls -la /config/

date
echo Finished - Full build
