#Bamboo lock file
lock_file=${bamboo_ATG_HOME}/bamboo.lock
lock_agent="${bamboo_buildKey}-${bamboo_buildNumber}"

if [ -f $lock_file ]; then
  #Check if this job is the lock owner
  lock_count=`grep -c $lock_agent $lock_file`
  if [ $lock_count = 1 ]; then
    rm $lock_file
    echo "ATG installation unlocked. (Lock file $lock_file deleted)"
  fi
fi