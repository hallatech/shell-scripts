#!/bin/bash

#This will monitor a server log file on startup until the server has started, then check for any logged errors.
#Uses SSH for remote server log monitoring to enable inclusion in Bamboo jobs
#Note: This does not handle rotated logfiles, and will just timeout waiting for the startup keys to be found
#      If you don't want to check rotated logfiles, use --no-check option

#Parameter defaults
SERVER_NAME=
DEBUG=false
USE_SSH=false
SSH_USER=
SSH_IDFILE=
SSH_HOST=
LOGFILE_NAME=
TARGET_ENV=
SHOW_WARNINGS=false
CHECK_STARTUP=true
SHOW_LOGS=true

#Local variables
#local log file defaults and base logfile
local_log_dir=/var/tmp/logs
local_logfile_name=nohup.jboss.live.out
local_logfile=$local_log_dir/$local_logfile_name
logfile=
log_entries=
#Startup complete log keys
logfile_eols_key1="started in"
logfile_eols_key2="Controller Boot Thread"
#Sleep time in between parsing iterations
sleep_time=5
#Max iterations to parse
max_iterations=40
#Log file parse iterations
parse_iterations=0
#Log startup successful key found 
log_eols_key_found=false
#Optional SSH identity file
ssh_identity=""
#Overridden/derived SSH host name
ssh_host_name=
#Show errors or warnings
log_type=ERROR
log_type_msg=errors


#Environment mappings
#Array indeces for 3.x older versions of bash
dev_idx=0
dev3_idx=1
dev4_idx=2
tst_idx=3
uat1_idx=4
uat2_idx=5
uat3_idx=6
uat4_idx=7
prf1_idx=8
prf2_idx=9
prf3_idx=10
prf4_idx=11

current_idx=0
env_idx=
env_server=

app1_idx=0
app2_idx=1
aux1_idx=2
merch1_idx=3
csc1_idx=4

#Configure environment mapping
declare -a ENVIRONMENTS
ENVIRONMENTS[$dev_idx]="dev"
ENVIRONMENTS[$dev3_idx]="dev3"
ENVIRONMENTS[$dev4_idx]="dev4"
ENVIRONMENTS[$tst_idx]="tst"
ENVIRONMENTS[$uat1_idx]="uat1"
ENVIRONMENTS[$uat2_idx]="uat2"
ENVIRONMENTS[$uat3_idx]="uat3"
ENVIRONMENTS[$uat4_idx]="uat4"
ENVIRONMENTS[$prf1_idx]="prf1"
ENVIRONMENTS[$prf2_idx]="prf2"
ENVIRONMENTS[$prf3_idx]="prf3"
ENVIRONMENTS[$prf4_idx]="prf4"

declare -a ENV_SERVERS
ENV_SERVERS[$dev_idx]="server-dev-prefix-app-01-server.com"
ENV_SERVERS[$dev3_idx]="server-dev-prefix-app-03-server.com"
ENV_SERVERS[$dev4_idx]="server-dev-prefix-app-04-server.com"
ENV_SERVERS[$tst_idx]="server-dev-prefix-app-02-server.com"
ENV_SERVERS[$uat1_idx]="server-uat-prefix-app-01-server.com"
ENV_SERVERS[$uat2_idx]="server-uat-prefix-app-02-server.com"
ENV_SERVERS[$uat3_idx]="server-uat-prefix-app-03-server.com"
ENV_SERVERS[$uat4_idx]="server-uat-prefix-tool-01-server.com"
ENV_SERVERS[$prf1_idx]="server-prf-prefix-app-01-server.com"
ENV_SERVERS[$prf2_idx]="server-prf-prefix-app-02-server.com"
ENV_SERVERS[$prf3_idx]="server-prf-prefix-app-03-server.com"
ENV_SERVERS[$prf4_idx]="server-prf-prefix-tool-01-server.com"

declare -a dev_server_logs
dev_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/dev1/app1/server.log"
dev_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/dev1/app2/server.log"
dev_server_logs[$aux1_idx]="/opt/oracle/commerce/var/log/dev1/aux1/server.log"
dev_server_logs[$merch1_idx]="/opt/oracle/commerce/var/log/dev1/merch1/server.log"
dev_server_logs[$csc1_idx]="/opt/oracle/commerce/var/log/dev1/csc1/server.log"

declare -a tst_server_logs
tst_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/dev2/app1/server.log"
tst_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/dev2/app2/server.log"
tst_server_logs[$aux1_idx]="/opt/oracle/commerce/var/log/dev2/aux1/server.log"
tst_server_logs[$merch1_idx]="/opt/oracle/commerce/var/log/dev2/merch1/server.log"
tst_server_logs[$csc1_idx]="/opt/oracle/commerce/var/log/dev2/csc1/server.log"
tst_server_logs[$preview1_idx]="/opt/oracle/commerce/var/log/dev2/preview1/server.log"

declare -a uat1_server_logs
uat1_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/uat1/app1/server.log"
uat1_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/uat1/app2/server.log"
uat1_server_logs[2]="/opt/oracle/commerce/var/log/uat1/aux1/server.log"

declare -a uat2_server_logs
uat2_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/uat1/app1/server.log"
uat2_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/uat1/app2/server.log"
uat2_server_logs[2]="/opt/oracle/commerce/var/log/uat1/aux2/server.log"

declare -a uat3_server_logs
uat3_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/uat1/app1/server.log"
uat3_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/uat1/app2/server.log"

declare -a uat4_server_logs
uat4_server_logs[0]="/opt/oracle/commerce/var/log/uat1/merch1/server.log"
uat4_server_logs[1]="/opt/oracle/commerce/var/log/uat1/csc1/server.log"
uat4_server_logs[2]="/opt/oracle/commerce/var/log/uat1/preview1/server.log"

declare -a prf1_server_logs
prf1_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/prf1/app1/server.log"
prf1_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/prf1/app2/server.log"
prf1_server_logs[2]="/opt/oracle/commerce/var/log/prf1/aux1/server.log"

declare -a prf2_server_logs
prf2_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/prf1/app1/server.log"
prf2_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/prf1/app2/server.log"
prf2_server_logs[2]="/opt/oracle/commerce/var/log/prf1/aux2/server.log"

declare -a prf3_server_logs
prf3_server_logs[$app1_idx]="/opt/oracle/commerce/var/log/prf1/app1/server.log"
prf3_server_logs[$app2_idx]="/opt/oracle/commerce/var/log/prf1/app2/server.log"

declare -a prf4_server_logs
prf4_server_logs[0]="/opt/oracle/commerce/var/log/prf1/merch1/server.log"
prf4_server_logs[1]="/opt/oracle/commerce/var/log/prf1/csc1/server.log"
prf4_server_logs[2]="/opt/oracle/commerce/var/log/prf1/preview1/server.log"

function usage {
  echo "usage: monitorStartupLogs.sh [[-e environment | -l logfile [-t hostname]] [-d] [--ssh -u user [-i identity-file]] [-w] [-n] [-o] [-h]]"
  echo "  Parameters:"
  echo "  -s | --server     : Specify the servername to use: default=$SERVER_NAME"
  echo "  --ssh             : Use SSH for remote logs"
  echo "  -u | --ssh-user   : SSH username"
  echo "  -i | --ssh-idfile : SSH identity-file"
  echo "  -t | --ssh-host   : SSH host"
  echo "  -n | --no-check   : Don't check logs for startup keys (in case of log rotation)"
  echo "  -w | --warnings   : Show log WARNINGs instead of ERRORs"
  echo "  -o | --no-output  : Don't show actual logs just whether they have any of the requested log type"
  echo "  -e | --env        : Target environment to parse log files from"
  echo "  -l | --logfile    : Use named logfile"
  echo "  -d | --debug      : Show debug messages"
  echo "  -h | --help       : Show this usage message"
  echo "-------------------------------------------------------------------------------------------------"
  echo "Remote requirements: Setup up private/public key pairs on each server for SSH acces:"
  echo "Useful URL for setup: http://support.pa.msu.edu/howto.php?id=51"
  echo "Supported Environments: dev, dev3, dev4, tst, uat1, uat2, uat3, uat4"
  echo "Examples:"
  echo "1. Check logs for errors on DEV3"
  echo "   buildtools/bin/monitorStartupLogs.sh -e dev3 -u username -i ~/.ssh/id_rsa"
  echo "2. Check logs for warnings on DEV4 but don't check for startup as logs have rotated"
  echo "   buildtools/bin/monitorStartupLogs.sh -e dev4 -u username -i ~/.ssh/id_rsa --warnings --no-check"
  echo "3. Check logs for errors on UAT but don't show actual log errors. UAT has 4 servers and logs have rotated"
  echo "   envs=( uat1 uat2 uat3 uat4 ); for i in \"\${envs[@]}\"; do buildtools/bin/monitorStartupLogs.sh -e \$i -u username -i ~/.ssh/my-private-key --no-check --no-output; done"
  echo "-------------------------------------------------------------------------------------------------"
}

function log_error {
  echo "ERROR: $1"
  if [ "$2" = "" ]; then
    exit 1
  else
    exit $2
  fi
}

function log_internal_error {
  echo "ERROR (Internal): $1"
  if [ "$2" = "" ]; then
    exit 1
  else
    exit $2
  fi
}

function log_debug {
  if [ "$DEBUG" = "true" ]; then
    echo "DEBUG: $1"
  fi
}

function set_ssh_host_name {
  ssh_host_name=$SSH_HOST
  log_debug "set_ssh_host_name:(pre)ssh_host_name=$ssh_host_name"
  if [ "${ssh_host_name}" = "" ]; then
    get_environment_index $TARGET_ENV
    if [ ! "$env_idx" = "" ]; then
      ssh_host_name=${ENV_SERVERS[env_idx]}
    fi
  fi
  log_debug "set_ssh_host_name:(post)ssh_host_name=$ssh_host_name"
}

function check_server_started {
  result=
  if [ $USE_SSH ]; then
    result=$( ssh -q $ssh_identity $SSH_USER@$ssh_host_name "cat $logfile | grep \"$logfile_eols_key1\" | grep \"$logfile_eols_key2\"" )
  else
    result=$( cat $logfile | grep "$logfile_eols_key1" | grep "$logfile_eols_key2" )
  fi
  log_debug "result=$result"
  if [ ! "$result" = "" ]; then
    log_eols_key_found=true
  fi
  log_debug log_eols_key_found=$log_eols_key_found
}

function check_logfile_for_log_type_entries {
  log_entries=
  if [ $USE_SSH ]; then
    if [ "$1" = "display_errors" -a "$SHOW_LOGS" = "true" ]; then
      ssh -q $ssh_identity $SSH_USER@$ssh_host_name "cat $logfile | grep $log_type"
    else
      log_entries=$( ssh -q $ssh_identity $SSH_USER@$ssh_host_name "cat $logfile | grep $log_type" )
    fi
  else
    if [ "$1" = "display_errors" -a "$SHOW_LOGS" = "true" ]; then
      cat $logfile | grep $log_type
    else
      log_entries=$( cat $logfile | grep $log_type )
    fi
  fi
}

function check_logfile_exists {
  if [ "$USE_SSH" ]; then
    if ssh -q $ssh_identity $SSH_USER@$ssh_host_name test -e $logfile; then
       log_debug "Remote logfile [$logfile] exists"
    else
       log_error "Configured remote logfile [$logfile] does not exist"
       exit 1
    fi
  else
    if [ ! -f $logfile ]; then
      echo "Log file for [$SERVER_NAME] in [$logfile] not found."
      exit 1
    fi
  fi
  log_debug logfile=$logfile,LOGFILE_NAME=$LOGFILE_NAME
}

function get_environment_server {
  env_server=
  env_server=${ENV_SERVERS[env_idx]}
  if [ "${env_server}" = "" ]; then
    log_internal_error "Environment host name not found or configured." 6
  fi
}

function wait_until_server_started {
  log_eols_key_found=false
  parse_iterations=0
  if [ "$CHECK_STARTUP" = "true" ]; then
    until [ $parse_iterations -eq $max_iterations -o $log_eols_key_found = "true" ]; do
      if [ $parse_iterations -gt 0 ]; then
        log_debug "Sleeping for [$sleep_time]s"
        sleep $sleep_time
      fi
      check_server_started
      let parse_iterations=parse_iterations+1
      log_debug "Parsed $logfile $parse_iterations time(s)"
    done
  fi
}

#Note this function uses dynamic array substitution and the tricks to use it
#See: http://www.ludvikjerabek.com/2015/08/24/getting-bashed-by-dynamic-arrays/
function wait_until_all_servers_started {
  if [ "$1" = "" ]; then
    log_internal_error "No parameter supplied to function wait_until_all_servers_started" 5
  fi
  get_environment_server
  log_debug "Server=$env_server"
  server_log_array=$1_server_logs
  local max=$(eval echo \${\#${server_log_array}[@]})
  log_debug "local max = $max"
  for (( i = 0; i < ${max}; i++ )); do
    local lf=$( eval echo \${$server_log_array[$i]} )
    log_debug "logfile[$i]=${lf}"
    logfile=${lf}
    check_logfile_exists
    wait_until_server_started
  done
}

function show_server_startup_status {
  if [ "$log_eols_key_found" = "false" ]; then
    echo "Server [$SERVER_NAME] for logfile [$logfile] failed to startup in maximum time $( expr $max_iterations \* $sleep_time )s."
    exit 1
  fi
  echo "Server [$SERVER_NAME] for logfile [$logfile] startup complete."
}

function check_for_log_type_entries {
  #Check the log for errors and display them
  check_logfile_for_log_type_entries
  
  if [ ! "$log_entries" = "" ]; then
    printf "\nStartup log $log_type_msg found in $logfile\n"
    #log_entries doesn't preserve the line breaks so just repeat the command
    check_logfile_for_log_type_entries display_errors
    if [ "$1" = "" -o "$1" = "true" ]; then
      exit 2
    fi
  else
    echo "No log $log_type_msg found in $logfile"
  fi
}

function check_all_logs_for_log_type_entries {
  if [ "$1" = "" ]; then
    log_internal_error "No parameter supplied to function check_all_logs_for_log_type_entries" 7
  fi
  get_environment_server
  log_debug "Server=$env_server"
  server_log_array=$1_server_logs
  local max=$(eval echo \${\#${server_log_array}[@]})
  log_debug "local max = $max"
  for (( i = 0; i < ${max}; i++ )); do
    local lf=$( eval echo \${$server_log_array[$i]} )
    log_debug "logfile[$i]=${lf}"
    logfile=${lf}
    if [ $i -eq $max ]; then
      check_for_log_type_entries "true"
    else
      check_for_log_type_entries "false"
    fi
done
}

function get_environment_index {
  for (( i = 0; i < ${#ENVIRONMENTS[@]}; i++ )); do
    log_debug "get_environment_index,i=$i,ENVIRONMENTS[$i]=${ENVIRONMENTS[$i]}"
    if [ "${ENVIRONMENTS[$i]}" == $1 ]; then
      env_idx=$i
    fi
  done
}

#Process command line parameters
while [ "$1" != "" ]; do
  case $1 in
    -s | --servername ) shift
                        SERVER_NAME=$1
                        ;;
    -l | --logfile )    shift
                        LOGFILE_NAME=$1
                        ;;
    -n | --no-check )   CHECK_STARTUP=false
                        ;;
    -d | --debug )      DEBUG=true
                        ;;
    -w | --warnings )   SHOW_WARNINGS=true
                        ;;
    -o | --no-output )  SHOW_LOGS=false
                        ;;
    --ssh )             USE_SSH=true
                        ;;
    -u | --ssh-user )   shift
                        SSH_USER=$1
                        ;;
    -i | --ssh-idfile ) shift
                        SSH_IDFILE=$1
                        ;;
    -t | --ssh-host )   shift
                        SSH_HOST=$1
                        ;;
    -e | --env )        shift
                        TARGET_ENV=$1
                        ;;
    -h | --help )       usage
                        exit
                        ;;
    * )                 usage
                        exit 1
  esac
  shift
done

#Check options
if [ ! "${TARGET_ENV}x" = "x" -a ! "${LOGFILE_NAME}x" = "x" ]; then
  log_debug "TARGET_ENV=$TARGET_ENV,LOGFILE_NAME=$LOGFILE_NAME"
  log_error "Enter either a target environment or a logfile but not both." 2
  usage
  exit 1
fi
if [ ! "${TARGET_ENV}x" = "x" -a "${SSH_USER}x" = "x" ]; then
  log_error "You must specify a SSH user if a a target environment is specified." 3
  usage
  exit 1
fi

#Configure SSH identity file and option if available
if [ ! "${USE_SSH}x" = "x" -a ! "${SSH_IDFILE}x" = "x" ]; then
  ssh_identity="-i $SSH_IDFILE"
fi

#Configure SSH host
log_debug "TARGET_ENV=$TARGET_ENV,SSH_HOST=$SSH_HOST"
if [ ! "${TARGET_ENV}x" = "x" -a "${SSH_HOST}x" = "x" ]; then
  set_ssh_host_name
  log_debug "hostname=$ssh_host_name"
fi

#Configure ERRORs or WARNINGs
if [ "$SHOW_WARNINGS" = "true" ]; then
  log_type=WARN
  log_type_msg=warnings
fi
#If a logfile is supplied, confirm log file exists for running server
#Process log file until startup complete and check for errors
if [ ! "${LOGFILE_NAME}x" = "x" ]; then
  logfile=$LOGFILE_NAME
  check_logfile_exists
  wait_until_server_started
  show_server_startup_status
  check_for_log_type_entries
fi

#If an environement is supplied, check and process all server logs
if [ ! "$TARGET_ENV" = "" ]; then
  get_environment_index $TARGET_ENV
  if [ "${env_idx}x" = "x" ]; then
    log_error "Invalid environment specified: [$TARGET_ENV]" 4
  fi
  echo "Checking server logs for $log_type_msg in environment $TARGET_ENV ($ssh_host_name)..."
  wait_until_all_servers_started $TARGET_ENV
  check_all_logs_for_log_type_entries $TARGET_ENV
fi

