#!/bin/sh

# set -e -o pipefail

date
echo Started - Deploy

if [ ! -f pom.xml ]; then
    echo "The current working directory ($PWD) does not contain a maven project"
    exit 1
fi

CONFIGDIR=$(dirname $(find /projects/myapp/target/liberty/wlp/usr/servers -name server.xml))
if [ ! $? -eq 0 ]; then
    echo "Cannot start the server because the config directory could not be found"
    exit 1
fi

cp /data/shared /opt/ol/wlp/usr/shared/
cp /data/configlibdir/ /config
cp /data/config/ /config/
cp /data/config/apps/*.[ew]ar /config/apps

date
echo AJM Starting the server
server run

date
echo Finished - Run