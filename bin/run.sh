#!/bin/sh

# set -e -o pipefail

date
echo Started - Run

if [ ! -f pom.xml ]; then
    echo "The current working directory ($PWD) does not contain a maven project"
    exit 1
fi

CONFIGDIR=$(dirname $(find /projects/openLiberty/target/liberty/wlp/usr/servers -name server.xml))
if [ ! $? -eq 0 ]; then
    echo "Cannot start the server because the config directory could not be found"
    exit 1
fi

date
echo AJM Starting the server
server run

date
echo Finished - Run
