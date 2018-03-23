#!/bin/bash

#Alternatives for the bcc instance e.g. Publishing, CA, BCC etc
declare -a ATG_INSTANCES
ATG_INSTANCES[0]="Publishing"
ATG_INSTANCES[1]="BCC"

for server in "${ATG_INSTANCES[@]}"
do
  LIVEPID=`ps -ef | grep java | grep $server | grep -v grep | awk '{print $2}'`
  if [ ! "$LIVEPID" = "" ]; then
    server_name=`ps -ef | grep java | grep $server | awk -F"atg.dynamo.server.name=" '{print $2}' | cut -f1 -d' '`
    echo "ATG Server $server_name killed."
    kill -9 $LIVEPID
    exit 0
  fi
done
echo "No ATG Server found to stop, no action taken."
