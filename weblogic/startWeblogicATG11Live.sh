#!/bin/sh

#Parameter defaults
DOMAIN=live
RUN_BG=fg
MEM_XMX=1024m
USE_REBEL=true
REBEL_LOGGING=false
DEBUG=true
USE_TAKIPI=false
FORCE_INDEX=false
CLEAN_CACHES=false
DEFAULT_LOCAL_LAYERS="store:store-local"
SWITCHING_LAYERS="store-switching"
LAYERS=$DEFAULT_LOCAL_LAYERS

function usage {
  echo "usage: startWeblogicATG11Live.sh [[ -d domain ] [-b | -f] [-x memXmx] [-n] [-r] [-s] [-l | --layers][--no-debug] [-t | --takipi] [-h]]"
  echo "  Parameters:"
  echo "  -d | --domain     : Specify the domain to use: default=$DOMAIN"
  echo "  -b | --background : Run in background."
  echo "  -f | --foreground : Run in foreground (default)."
  echo "  -x | --xmx        : Specify the amount of XMX memory to use: default=$MEM_XMX"
  echo "  -n | --no-rebel   : Don't use JRebel."
  echo "  -r | --log-rebel  : Activate JRebel logging."
  echo "  --no-debug        : Disable debugging."
  echo "  -l | --layer      : Use optional layer(s) on startup: default=$LAYERS. Choose one or more layers. Separate with :, e.g. store:store-local"
  echo "  -s | --switching  : Add switching layer(s) on startup: default=$LAYERS + switching: $SWITCHING_LAYERS"
  echo "  -t | --takipi     : Activate Takipi."
  echo "  -i | --index      : Force and index. Runs by default on first startup"
  echo "  -c | --clean      : Clean temporary WLS application caches before startup."
  echo "  -h | --help       : Show options."
}

#Process command line parameters
while [ "$1" != "" ]; do
  case $1 in
    -d | --domain )     shift
                        DOMAIN=$1
                        ;;
    -f | --foreground ) RUN_BG=fg
                        ;;
    -b | --background ) RUN_BG=bg
                        ;;
    -x | --xmx )        shift
                        MEM_XMX=$1
                        ;;
    --no-debug )        DEBUG=false
                        ;;
    -n | --no-rebel )   USE_REBEL=false
                        ;;
    -r | --log-rebel )  REBEL_LOGGING=true
                        ;;
    -t | --takipi )     USE_TAKIPI=true
                        ;;
    -l | --layer )      shift
                        LAYERS=$1
                        ;;
    -s | --switching )  shift
                        LAYERS="${DEFAULT_LOCAL_LAYERS}:${SWITCHING_LAYERS}"
                        ;;
    -i | --index )      FORCE_INDEX=true
                        ;;
    -c | --clean )      CLEAN_CACHES=true
                        ;;
    -h | --help )       usage
                        exit
                        ;;
    * )                 usage
                        exit 1
  esac
  shift
done

echo "Runtime parameters: DOMAIN=$DOMAIN,RUN_BG=$RUN_BG,USE_REBEL=$USE_REBEL,MEM_XMX=$MEM_XMX,FORCE_INDEX=$FORCE_INDEX,LAYERS=$LAYERS"

user_projects_dir="/opt/Oracle/Middleware/user_projects"
APPLICATIONS_DIR="$user_projects_dir/applications"
DOMAINS_DIR="$user_projects_dir/domains"
DOMAIN_HOME=$DOMAINS_DIR/$DOMAIN
if [ ! -d $DOMAIN_HOME ]; then
  echo "No valid Weblogic domain found for: $DOMAIN_HOME. Either create the domain or pass in a valid domain name to this script."
  usage
  exit -1
fi

source $HOME/.bash_profile

#Deleting any existing port configuration in localconfig
config="$ATG_HOME/home/localconfig/atg/dynamo/Configuration.properties"
if [ -e $config ]; then
  echo "Deleting $config to avoid port conflict."
  rm $config
fi

#Check for Endeca indexing config. Force if not found or explicitly specified
indexFileParentPath="$ATG_HOME/home/localconfig/hallatech/search/endeca"
indexFile="$indexFileParentPath/ScheduledSearchIndexService.properties"
if [ -e $indexFile ]; then
  if [ "$FORCE_INDEX" = "true" ]; then
    echo "indexingEnabled=true" > $indexFile
  else
    echo "indexingEnabled=false" > $indexFile
  fi
else
  if [ ! -e "$indexFileParentPath" ]; then
    mkdir -p $indexFileParentPath
  fi
  touch $indexFile
  echo "indexingEnabled=true" > $indexFile
fi

# ATG Server Name
if [ "x$ATG_LIVE_SERVER_NAME" = "x" ]; then
  ATG_LIVE_SERVER_NAME="AdminServer"
fi

LOG4J_CONFIG_FILE=${DOMAIN_HOME}/config/log4j.xml
if [ ! -f $LOG4J_CONFIG_FILE ]; then
  echo "WARNING: No valid log4j file deployed to $LOG4J_CONFIG_FILE. ATG logging will be restricted or missing from the logs."
fi
JAVA_OPTIONS="${JAVA_OPTIONS} -Dweblogic.Name=${ATG_LIVE_SERVER_NAME} -Datg.dynamo.server.name=atg_production_lockserver -Datg.instance.name=Storefront -Dweblogic.log.Log4jLoggingEnabled -Dlog4j.configuration=file:$LOG4J_CONFIG_FILE"

TITLE='ATG Live ('$ATG_LIVE_SERVER_NAME')'

#Add ATG layers
JAVA_OPTIONS="${JAVA_OPTIONS} -Datg.dynamo.layers=${LAYERS}"

# Logs directory
LOG_DIR=/tmp/logs
BG_LOG_FILE=nohup.weblogic.live.out
if [ ! -d $LOG_DIR ]; then mkdir -p $LOG_DIR; fi

java_version=$(cat $JAVA_HOME/release | grep JAVA_VERSION)
if [ "x$java_version" = "x" ]; then
  java_version=$(java -version 2>/tmp/jv && cat /tmp/jv | grep version)
fi
maxPermSize=""
if [[ "$java_version" == *1.6* || "$java_version" == *1.7* ]]; then
  maxPermSize="-XX:MaxPermSize=256m"
fi 

# Weblogic memory options are set using USER_MEM_ARGS
USER_MEM_ARGS="-Xms512m -Xmx$MEM_XMX $maxPermSize"
export USER_MEM_ARGS

# Remote Debug
if [ "$DEBUG" = "true" ]; then
  JAVA_OPTIONS="${JAVA_OPTIONS} -Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
fi

# Fast shutdown - live only
JAVA_OPTIONS="${JAVA_OPTIONS} -Xrs"

# Dev only fast startup of admin console
JAVA_OPTIONS="${JAVA_OPTIONS} -Djava.security.egd=file:/dev/./urandom"

# JREBEL
jr_version=$(ls -la $REBEL_HOME | grep rebel/7)
if [ "$USE_REBEL" = "true" -a "x$REBEL_HOME" != "x" ]; then
  if [ "x$jr_version" = "x" ]; then
    #JRebel 6.x and earlier
    JAVA_OPTIONS="$JAVA_OPTIONS -javaagent:$REBEL_HOME/jrebel.jar -Drebel.workspace.path=$HOME/workspace -Drebel.resource_cache=false"
  else
    #JRebel 7.x and later
    JAVA_OPTIONS="$JAVA_OPTIONS -agentpath:$REBEL_HOME/lib/libjrebel64.so -Drebel.workspace.path=$HOME/workspace -Drebel.resource_cache=false"
  fi
fi

# Takipi monitoring
if [ "$USE_TAKIPI" = "true" ]; then
  JAVA_OPTIONS="$JAVA_OPTIONS -agentlib:TakipiAgent -Dtakipi.name=atg_production_lockserver"
fi

# Apache http client logging. Please note the trace will be printed in the serverlog.
# Its location might vary.
#JAVA_OPTIONS="$JAVA_OPTIONS -Dorg.apache.commons.logging.Log=org.apache.commons.logging.impl.SimpleLog"
#JAVA_OPTIONS="$JAVA_OPTIONS -Dorg.apache.commons.logging.simplelog.showdatetime=true"
#JAVA_OPTIONS="$JAVA_OPTIONS -Dorg.apache.commons.logging.simplelog.log.org.apache.http=DEBUG"

# Add atglib for JPS
JAVA_OPTIONS="${JAVA_OPTIONS} -Datg.atglib.dir=${ATG_HOME}"

export JAVA_OPTIONS

# Classpath configuration to ensure certain jar are loaded first on classpath. jar preference is also controlled within weblogic-application.xml
PROTOCOL=protocol.jar
if [ ! -f ${DOMAIN_HOME}/lib/${PROTOCOL} ]; then
  cp ${ATG_HOME}/DAS/lib/${PROTOCOL} ${DOMAIN_HOME}/lib
fi
AXIS=axis-1.4.jar
if [ ! -f ${DOMAIN_HOME}/lib/${AXIS} ]; then
  cp ${ATG_HOME}/DAS/lib/${AXIS} ${DOMAIN_HOME}/lib
fi
LOGGING=commons-logging-1.1.1.jar
if [ ! -f ${DOMAIN_HOME}/lib/${LOGGING} ]; then
  cp ${ATG_HOME}/DAS/lib/${LOGGING} ${DOMAIN_HOME}/lib
fi
DISCOVERY=commons-discovery-0.2.jar
if [ ! -f ${DOMAIN_HOME}/lib/${DISCOVERY} ]; then
  cp ${ATG_HOME}/DAS/lib/${DISCOVERY} ${DOMAIN_HOME}/lib
fi

custom_pre_classpath="${DOMAIN_HOME}/lib/${PROTOCOL}:${DOMAIN_HOME}/lib/${AXIS}:${DOMAIN_HOME}/lib/${LOGGING}:${DOMAIN_HOME}/lib/${DISCOVERY}:"
export PRE_CLASSPATH=$custom_pre_classpath

#Clean caches on startup
if [ "$CLEAN_CACHES" = "true" ]; then
  cache_root=${DOMAIN_HOME}/servers/$ATG_LIVE_SERVER_NAME
  cache_dirs=(cache data tmp)
  for dir in ${cache_dirs[*]}; do
    if [ -d $cache_root/$dir ]; then
       echo "Deleting $cache_root/$dir"
       rm -rf $cache_root/$dir
    fi
  done
fi

printf "\nStarting Weblogic Admin Server in domain=${DOMAIN_HOME} ..."
printf "\nUsing custom PRE_CLASSPATH=${custom_pre_classpath}"
printf "\nTo view server output run tailLive.sh"
printf "\nTo terminate run stopLive.sh\n\n"

if [ "$RUN_BG" = "bg" ]; then
  nohup ${DOMAIN_HOME}/bin/startWebLogic.sh | $ATG_HOME/../ATGLogColorizer >  $LOG_DIR/$BG_LOG_FILE 2>&1 &
else
  ${DOMAIN_HOME}/bin/startWebLogic.sh | $ATG_HOME/../ATGLogColorizer
fi
