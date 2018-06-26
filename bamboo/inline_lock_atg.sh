#Check if lock file exists
lock_file=${bamboo_ATG_HOME}/bamboo.lock
lock_agent="${bamboo_buildKey}-${bamboo_buildNumber}"

if [ -f $lock_file ]; then
  echo "WARNING: ATG installation Bamboo lock file exists:"
  cat $lock_file
  if [ "${bamboo_UNLOCK_ATG_INSTALLATION}" = "true" ]; then
    echo "INFO: Overriding current lock file as UNLOCK_ATG_INSTALLATION=$bamboo_UNLOCK_ATG_INSTALLATION."
    rm $lock_file
  else
    echo "ERROR: Cannot proceed with build. Set UNLOCK_ATG_INSTALLATION=true to override."
    exit 1
  fi
else
  touch $lock_file
  echo "${lock_agent} " $( date ) > $lock_file
  echo "Created ATG installation lock"
  cat $lock_file
fi