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

echo AJM data contents:
find /stack -name "*"

echo AJM - validating the project
cp /stack/validate.sh /projects/user-app
cd /projects/user-app
./validate.sh build


echo AJM - building the pom now...

mvn -B liberty:install-server
mvn -B -Pappsody-build -Dmaven.repo.local=/root/.m2/repository -DskipTests=true liberty:create package
#mvn -B clean package -Dmaven.repo.local=/home/user/.m2/repository -DskipTests=true liberty:create
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
#CONFIGDIR=$(dirname $(find /projects/myapp/target/liberty/wlp/usr/servers -name server.xml))
#if [ ! $? -eq 0 ]; then
#    echo "Cannot start the server because the config directory could not be found"
#    exit 1
#fi

rm -rf /data/config/*

CONFIGDIR=$(dirname $(find /projects/user-app/target/liberty/wlp/usr/servers -name server.xml))
if [ ! $? -eq 0 ]; then
    echo "Cannot start the server because the config directory could not be found"
    exit 1
fi

echo AJM: configdir = $CONFIGDIR

mkdir -p /data/config/apps
mkdir -p /data/config/resources
chown -R java_user:java_group /data/config
# make a well known place for shared library jars seperate from the rest of the defaultServer contents (to help with caching)
mkdir /data/configlibdir
chown -R java_user:java_group /data/configlibdir
mkdir /data/shared
chown -R java_user:java_group /data/shared

cd $CONFIGDIR
if [ -d ./defaultServer/lib ]; then mv ./defaultServer/lib /data/configlibdir; fi
if [ ! -d /configlibdir/lib ]; then mkdir /data/configlibdir/lib; fi
mv -f ./* /data/config/
if [ -d ../shared ]; then mv ../shared/* /data/shared/; fi
cd -
cp ./target/*.[ew]ar /data/config/apps

#rm -rf /config/*
#cp -r $CONFIGDIR/* /config/
#cp -r resources /opt/ol/wlp/output/defaultServer
ls -la /data/config/

date
echo Finished - Full build
