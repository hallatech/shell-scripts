#!/bin/bash

## ============================================================================
## Bamboo switch checked out branch to a tag based on deployment tag parameter
## ============================================================================

if [ -f buildtools/bin/gitCheckTagParameter.sh ]; then
  buildtools/bin/gitCheckTagParameter.sh
fi

echo "Creating local branch for tag ${bamboo_DEV_DEPLOYMENT_TAG}"

#Fetch the tags - appears to be done with repo checkout - but sometimes not ?
git fetch --tags origin

#Check the requested tag is valid
valid_tag=$(git show-ref --tags | grep ${bamboo_DEV_DEPLOYMENT_TAG})
echo "Tag ${bamboo_DEV_DEPLOYMENT_TAG} ref=${valid_tag}"

if [ "${valid_tag}" = "" ]; then
  echo "Failed to find valid tag reference for ${bamboo_DEV_DEPLOYMENT_TAG}"
  echo "Valid tags are:"
  git show-ref --tags
  exit 1
fi

#You can't checkout a tag so create a local branch at the tag
local_branch_name=bamboo_deploy_for_${bamboo_DEV_DEPLOYMENT_TAG}
echo "Creating a local branch ${local_branch_name} for ${bamboo_DEV_DEPLOYMENT_TAG}"
git checkout -b ${local_branch_name} ${bamboo_DEV_DEPLOYMENT_TAG}
git status

