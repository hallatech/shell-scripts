#Make sure tags are up to date
git fetch --tags origin

deploy_tag=""
if [ "x${bamboo_DEV_DEPLOYMENT_TAG}" = "x" -o "${bamboo_DEV_DEPLOYMENT_TAG}" = "Enter_valid_build_tag_at_runtime" ]; then
  echo "Warning: required DEV_DEPLOYMENT_TAG is not set - will use latest tag."
  deploy_tag=$( git describe --abbrev=0 --tags --match="*$( git rev-parse --abbrev-ref HEAD)" )
  if [ "x$deploy_tag" = "x" ]; then
    echo "Latest tag not found - cannot progress deployment"
    exit 1
  fi
else
  echo "Plan can execute with supplied DEV_DEPLOYMENT_TAG=${bamboo_DEV_DEPLOYMENT_TAG}"
  deploy_tag=${bamboo_DEV_DEPLOYMENT_TAG}
fi
echo "Executing deployment with tag: $deploy_tag"

#Check the requested tag is valid
valid_tag=$(git show-ref --tags | grep $deploy_tag)
echo "Tag ${deploy_tag} ref=${valid_tag}"

if [ "${valid_tag}" = "" ]; then
  echo "Failed to find valid tag reference for ${deploy_tag}"
  echo "Valid tags are:"
  git show-ref --tags
  exit 1
fi

#Save the resultant deploy tag in case it's different from DEV_DEPLOYMENT_TAG
echo "deploy_tag=$deploy_tag" > injected_bamboo_vars

#You can't checkout a tag so create a local branch at the tag
local_branch_name=bamboo_deploy_for_${deploy_tag}
echo "Creating a local branch ${local_branch_name} for ${deploy_tag}"
git checkout -b ${local_branch_name} ${deploy_tag}
git status
