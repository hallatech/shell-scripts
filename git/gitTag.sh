#!/bin/bash

## ============================================================================
## Create a git tag for this project from Bamboo
## Uses the version.properties to pick up the version and for bash processing
## converts any periods in the version to underscores to read the file, then
## reverts to periods when setting the version
## ============================================================================

echo "Git Version: $(git --version)"
echo "Prepare version number..."
cat version.properties | sed 's/\./_/g' > build/version.properties
source build/version.properties
current_version=${version//_/.}
echo "Current Version: ${current_version}"

echo "Creating tag using Bamboo properties:"
echo "revisionNumber: ${bamboo_planRepository_1_revision}"
echo "buildNumber: ${bamboo_buildNumber}"
echo "buildResultKey: ${bamboo_buildResultKey}"
echo "branchName: ${bamboo_planRepository_1_branch}"

export tagged_version=v${current_version}.${bamboo_buildNumber}-${bamboo_planRepository_1_branch}
echo "Tag: ${tagged_version}"

#Configure user credentials
git config user.name "<git-username>"
echo "Git user.name:"
git config --get user.name
git config user.email "<git-email>"
echo "Git user.email:"
git config --get user.email

#Tag the version
echo "Tagging Git Repository..."
git tag -a ${tagged_version} -m "Bamboo Deployment version ${tagged_version} RevisionNumber: ${bamboo_planRepository_1_revision}"
git show ${tagged_version}
git config credential.helper store
git remote add sourcerepo https://path/to/repo.git
git remote set-url origin https://<git-username>@path/to/repo.git
git push sourcerepo ${tagged_version}
echo $tagged_version > build/tag_version.txt
