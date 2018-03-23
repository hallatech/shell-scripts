#!/bin/bash

#Parameter defaults
RUN_BG=fg
MEM_XMX=2000m
USE_REBEL=false
#LAYERS="Preview:staging:bcc:bcc-local:bcc-jboss"
LAYERS="Preview:bcc:bcc-local:bcc-jboss"
ATG_CA_SERVER_NAME="atg_publishing_lockserver"

function usage {
  echo "usage: startJBossATG11CA.sh [[-b] [-x memXmx] [-n] [-h] [-l layers][-s servername]"
  echo "  Parameters:"
  echo "  -b | --background : Run in background."
  echo "  -f | --foreground : Run in foreground."
  echo "  -s | --servername : Choose alternative servername. Default servername=$ATG_CA_SERVER_NAME"
  echo "  -x | --xmx        : Specify the amount of XMX memory to use: default=$MEM_XMX"
  echo "  -n | --no-rebel   : Don't use JRebel."
  echo "  -l | --layer      : Use optional layer(s) on startup: default=$LAYERS. Choose one or more layers. Separate with :, e.g. bcc:bcc-local"
}

#Process command line parameters
while [ "$1" != "" ]; do
  case $1 in
    -f | --foreground ) RUN_BG=fg
                        ;;
    -b | --background ) RUN_BG=bg
                        ;;
	-s | --servername ) shift
						ATG_CA_SERVER_NAME=$1
                        ;;
    -x | --xmx )        shift
                        MEM_XMX=$1
                        ;;
    -n | --no-rebel )   USE_REBEL=false
                        ;;
    -l | --layer )      shift
                        LAYERS=$1
                        ;;
    -h | --help )       usage
                        exit
                        ;;
    * )                 usage
                        exit 1
  esac
  shift
done

echo "Runtime parameters: RUN_BG=$RUN_BG,MEM_XMX=$MEM_XMX,USE_REBEL=$USE_REBEL,LAYERS=$LAYERS"

# Deleting any existing port configuration in localconfig
config="$ATG_HOME/home/localconfig/atg/dynamo/Configuration.properties"
if [ -e $config ]; then
  echo "Deleting $config to avoid port conflict."
  rm $config
fi

# ATG Server Name
TITLE='ATG CA ('$ATG_CA_SERVER_NAME')'
echo -n -e "\033]0;$TITLE\007"

#Add ATG layers
JAVA_OPTS="${JAVA_OPTS} -Datg.dynamo.layers=${LAYERS}"

# Logs directory
LOG_DIR=/tmp/logs
BG_LOG_FILE=nohup.jboss.ca.out

java_version=$(cat $JAVA_HOME/release | grep JAVA_VERSION)
if [ "x$java_version" = "x" ]; then
  java_version=$(java -version 2>/tmp/jv && cat /tmp/jv | grep version)
fi
maxPermSize=""
if [[ "$java_version" == *1.6* || "$java_version" == *1.7* ]]; then
  maxPermSize="-XX:MaxPermSize=256m"
fi

# JVM config
JAVA_OPTS="-Xms256m -Xmx$MEM_XMX $maxPermSize -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dsun.lang.ClassLoader.allowArraySyntax=true"

# Remote Debug
JAVA_OPTS="$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=8788,server=y,suspend=n"

# JMX
#JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote"
#JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote.port=3100"
#JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
#JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote.ssl=false"

# Headless VM, comment to use ACC
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true"

# JBOSS 6 Logging
JAVA_OPTS="$JAVA_OPTS -Djava.util.logging.manager=org.jboss.logmanager.LogManager"

# JREBEL
jr_version=$(ls -la $REBEL_HOME | grep rebel/7)
if [ "$USE_REBEL" = "true" -a "x$REBEL_HOME" != "x" ]; then
  if [ "x$jr_version" = "x" ]; then
    #JRebel 6.x and earlier
    JAVA_OPTS="$JAVA_OPTS -javaagent:$REBEL_HOME/jrebel.jar -Drebel.workspace.path=$HOME/workspace -Drebel.resource_cache=false"
  else
    #JRebel 7.x and later
    JAVA_OPTS="$JAVA_OPTS -agentpath:$REBEL_HOME/lib/libjrebel64.so -Drebel.workspace.path=$HOME/workspace -Drebel.resource_cache=false"
  fi
fi

# Set default JVM encoding to UTF-8
JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

# Add atglib for JPS
JAVA_OPTS="$JAVA_OPTS -Datg.atglib.dir=$ATG_HOME"

export JAVA_OPTS;

if [ "$RUN_BG" = "bg" ]; then
  if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
  fi
  nohup $JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -Datg.dynamo.server.name=$ATG_CA_SERVER_NAME --server-config ${ATG_CA_SERVER_NAME}.xml | $ATG_HOME/../ATGLogColorizer > $LOG_DIR/$BG_LOG_FILE 2>&1 &
  echo "JBoss ATG server $ATG_CA_SERVER_NAME started in background. Run tailLive.sh to view logs at $LOG_DIR/$BG_LOG_FILE"
else
  $JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -Datg.dynamo.server.name=$ATG_CA_SERVER_NAME --server-config ${ATG_CA_SERVER_NAME}.xml | $ATG_HOME/../ATGLogColorizer
fi
