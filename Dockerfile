# Step 1: Build the user's application
FROM kabanero/ubi8-maven:0.3.1 as compile

RUN  groupadd java_group \
   && useradd --gid java_group --shell /bin/bash --create-home java_user \
   && mkdir -p /mvn/repository \
   && chown -R java_user:java_group /mvn \
   && mkdir -p /config \
   && chown -R java_user:java_group /config \
# make a well known place for shared library jars seperate from the rest of the defaultServer contents (to help with caching)
   && mkdir /configlibdir \
   && chown -R java_user:java_group /configlibdir \
   &&  mkdir /shared \
   && chown -R java_user:java_group /shared 

 USER java_user

# Copy and build the dev.appsody:java-openliberty parent pom
COPY --chown=java_user:java_group ./pom.xml /project/pom.xml
RUN cd /project && mvn -B install dependency:go-offline -DskipTests

# Prime image
#   a) Prime .m2/repository with common artifacts 
#   b) Create target/liberty/wlp/usr/servers/defaultServer dir
COPY --chown=java_user:java_group ./preload-m2-pom.xml /project/user-app/preload-m2-pom.xml
RUN cd /project/user-app && \ 
    mvn -B -f /project/user-app/preload-m2-pom.xml liberty:install-server dependency:go-offline && \
    rm /project/user-app/preload-m2-pom.xml

# Copy and run a simple version check
COPY --chown=java_user:java_group ./util /project/util
RUN     /project/util/check_version build

# Copy the validate.sh script and application pom.xml
COPY --chown=java_user:java_group ./validate.sh /project/user-app/validate.sh
# -- This is the first app-specific piece --
# AJM COPY --chown=java_user:java_group ./user-app/pom.xml /project/user-app/pom.xml
# Validate 
# AJM RUN cd /project/user-app && ./validate.sh build

# Copy the rest of the application source
# AJM COPY --chown=java_user:java_group ./user-app /project/user-app

# Build (and run unit tests) 
#  also liberty:create copies config from src->target
#  also remove quick-start-security.xml since it's convenient for local dev mode but should not be in the production image.
# AJM RUN cd /project/user-app && \
#    rm -f src/main/liberty/config/configDropins/defaults/quick-start-security.xml && \
#    mvn -Pappsody-build -B liberty:create package

# process any resources or shared libraries - if they are present in the dependencies block for this project (there may be none potentially)
# test to see if each is present and move to a well known location for later processing in the next stage
# 
# AJM RUN cd /project/user-app/target/liberty/wlp/usr/servers && \
#    if [ -d ./defaultServer/lib ]; then mv ./defaultServer/lib /configlibdir; fi && \
#    if [ ! -d /configlibdir/lib ]; then mkdir /configlibdir/lib; fi && \
#    mv -f defaultServer/* /config/ && \
#    if [ -d ../shared ]; then mv ../shared/* /shared/; fi

# Step 2: Package Open Liberty image
# AJM FROM openliberty/open-liberty:19.0.0.12-kernel-java8-openj9-ubi

RUN chmod -R 777 /home/java_user/.m2/repository

FROM open-liberty

ENV JAVA_VERSION_PREFIX 1.8.0
ENV HOME /home/default

USER root

RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       amd64|x86_64) \
         YML_FILE='sdk/linux/x86_64/index.yml'; \
         ;; \
       i386) \
         YML_FILE='sdk/linux/i386/index.yml'; \
         ;; \
       ppc64el|ppc64le) \
         YML_FILE='sdk/linux/ppc64le/index.yml'; \
         ;; \
       s390) \
         YML_FILE='sdk/linux/s390/index.yml'; \
         ;; \
       s390x) \
         YML_FILE='sdk/linux/s390x/index.yml'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    apt-get update \
    && apt-get install -y --no-install-recommends wget openssl \
    && rm -rf /var/lib/apt/lists/*; \
    BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/"; \
    wget -q -U UA_IBM_JAVA_Docker -O /tmp/index.yml ${BASE_URL}/${YML_FILE}; \
    ESUM=$(cat /tmp/index.yml | sed -n '/'${JAVA_VERSION_PREFIX}'/{n;n;p}' | sed -n 's/\s*sha256sum:\s//p' | tr -d '\r' | tail -1); \
    JAVA_URL=$(cat /tmp/index.yml | sed -n '/'${JAVA_VERSION_PREFIX}'/{n;p}' | sed -n 's/\s*uri:\s//p' | tr -d '\r' | tail -1); \
    wget -q -U UA_IBM_JAVA_Docker -O /tmp/ibm-java.bin ${JAVA_URL}; \
    echo "${ESUM}  /tmp/ibm-java.bin" | sha256sum -c -; \
    echo "INSTALLER_UI=silent" > /tmp/response.properties; \
    echo "USER_INSTALL_DIR=$HOME/java" >> /tmp/response.properties; \
    echo "LICENSE_ACCEPTED=TRUE" >> /tmp/response.properties; \
    mkdir -p $HOME/java; \
    chmod +x /tmp/ibm-java.bin; \
    /tmp/ibm-java.bin -i silent -f /tmp/response.properties; \
    rm -f /tmp/response.properties; \
    rm -f /tmp/index.yml; \
    rm -f /tmp/ibm-java.bin; \
    cd $HOME/java/jre/lib; \
    rm -rf icc; \
    mkdir -p $HOME/mvn &&\
    MAVEN_VERSION=$(wget -qO- https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/maven-metadata.xml | sed -n 's/\s*<release>\(.*\)<.*>/\1/p') &&\
    wget -q -U UA_IBM_JAVA_Docker -O $HOME/mvn/apache-maven-${MAVEN_VERSION}-bin.tar.gz https://search.maven.org/remotecontent?filepath=org/apache/maven/apache-maven/${MAVEN_VERSION}/apache-maven-${MAVEN_VERSION}-bin.tar.gz &&\
    tar xf $HOME/mvn/apache-maven-${MAVEN_VERSION}-bin.tar.gz -C $HOME/mvn &&\
    mv $HOME/mvn/apache-maven-${MAVEN_VERSION} $HOME/mvn/apache-maven &&\
    rm -f $HOME/mvn/apache-maven-${MAVEN_VERSION}-bin.tar.gz; \
    apt-get purge --auto-remove -y wget; \
    rm -rf /var/lib/apt/lists/*;

RUN mkdir -m 777 -p /artifacts
RUN mkdir -m 777 -p /projects

USER 1001

RUN mkdir -m 777 -p /config/resources

COPY --chown=1001:0 bin/. /artifacts/bin
#COPY --chown=1001:0 --from=compile /project/user-app/target/liberty /projects/myapp/target

ENV JAVA_HOME=$HOME/java \
    PATH=$HOME/java/jre/bin:$HOME/mvn/apache-maven/bin:$PATH







#2a) copy any resources 
COPY --chown=1001:0 --from=compile /shared /opt/ol/wlp/usr/shared/

# 2b) next copy shared library
#      but can't assume config/lib exists - copy from previous stage to a tmp holding place and test
COPY --chown=1001:0 --from=compile /configlibdir/ /config

# 2c) Server config, bootstrap.properties, and everything else
COPY --chown=1001:0 --from=compile /config/ /config/

# 2d) get the mvn repo
COPY --chown=1001:0 --from=compile /home/java_user/.m2/repository /home/user/.m2/repository
#RUN mkdir -p /mvn/repository;
#RUN ln -s /home/user/.m2/repository /mvn/repository;

# 2d) Changes to the application binary
# AJM COPY --chown=1001:0 --from=compile /project/user-app/target/*.[ew]ar /config/apps
# AJM RUN configure.sh 
# AJM RUN chmod 664 /opt/ol/wlp/usr/servers/defaultServer/configDropins/defaults/keystore.xml
