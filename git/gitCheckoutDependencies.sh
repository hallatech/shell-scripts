#!/bin/bash

## ============================================================================
## Pull all git dependency projects from the parent directory
## Note: Due to older OSX versions of Bash, certain associative array options 
## are not available. 
## ============================================================================
WORKSPACE_HOME=..
CURRENT_DIR=`pwd`
LINE_HEADER='==================='
UPDATE_MAIN_PROJECT=true

function usage {
  echo "usage: gitCheckoutDependencies.sh [-x] [-h]"
  echo "  Parameters:"
  echo "  -x | --exclude    : Exclude main project update"
  echo "  -h | --help       : Show this usage message"
}

#Process command line parameters
while [ "$1" != "" ]; do
  case $1 in
    -x | --exclude )    UPDATE_MAIN_PROJECT=false
                        ;;
    -h | --help )       usage
                        exit
                        ;;
    * )                 usage
                        exit 1
  esac
  shift
done

#Get dependency versions by sourcing the version file. First convert all . to _
build_dir=build
version_file=version.properties

if [ ! -d $build_dir ]; then
  mkdir $build_dir
fi
#cat $version_file | sed 's/\./_/g' > $build_dir/$version_file
source $version_file

#Array indeces for 3.x older versions of bash
main_project_repo_idx=0
sub_repo_1_idx=1
sub_repo_2_idx=2

current_idx=0

#Configure dependency mapping
declare -a REPOSITORIES
REPOSITORIES[$main_project_repo_idx]="main-environment-repo"
REPOSITORIES[$sub_repo_1_idx]="repo1"
REPOSITORIES[$sub_repo_2_idx]="repo2"

#Configure dependency mapping
declare -a REPO_BRANCHES
REPO_BRANCHES[$main_project_repo_idx]="$branch"
REPO_BRANCHES[$sub_repo_1_idx]="$repo_1_branch"
REPO_BRANCHES[$sub_repo_2_idx]="$repo_2_branch"

#Configure dependency versions
declare -a VERSIONS
VERSIONS[$main_project_repo_idx]="$version"
VERSIONS[$sub_repo_1_idx]="$repo_1"
VERSIONS[$sub_repo_2_idx]="$repo_2"

#Checkout status
status_success=SUCCESS
declare -a UPDATE_STATUS

# Get the index using the repository name 
# @param repositoryName
function set_index {
  for (( i = 0; i < ${#REPOSITORIES[@]}; i++ )); do
    if [ "${REPOSITORIES[$i]}" == $1 ]; then
      current_idx=$i
    fi
  done
}

#Process all repository dependencies
for product in "${REPOSITORIES[@]}"; do
  set_index $product
  echo $LINE_HEADER $product $LINE_HEADER
  msg=$status_success

  if [ -d $WORKSPACE_HOME/$product ]; then
    cd $WORKSPACE_HOME/$product  
    if [ -d .git ]; then
      if [ "${UPDATE_MAIN_PROJECT}" = "false" ] && [ $current_idx -eq $main_project_repo_idx ] ; then
        msg="INFO: Current branch $on_branch not switched or updated."
      else
        git fetch --prune
        branch=${REPO_BRANCHES[$current_idx]}
        on_branch=$( git status | grep "On branch" | awk -F' ' '{ print $3 }')
        if [ ! "$on_branch" = "$branch" ]; then
          echo "Current branch = $on_branch, checking out $branch"
          git checkout $branch
          msg="INFO: Branch switched from $on_branch to $branch"
        fi
        git pull
        git status
        on_branch=$( git status | grep "On branch" | grep $branch)
        if [ "$on_branch" = "" ]; then
          msg="ERROR: Failed to check out $branch. Please check errors above."
        fi
      fi    
      UPDATE_STATUS[$current_idx]=$msg
    else
      msg="ERROR: $product directory already exists but not a valid git directory"
      UPDATE_STATUS[$current_idx]="$msg"
      echo $msg
    fi
  else
    msg="WARNING: $product directory does not exist. The project was not updated."
    UPDATE_STATUS[$current_idx]="$msg"
  fi 
done

#Print checkout results
padlength=30
pad=$(printf '%0.1s' " "{1..40})
repo_hdr=Repository
echo "" && printf "%0.s-" {1..120}
echo "" && echo "Checkout status:"
printf '%s%*.*s%-20s%-20s%s\n' "${repo_hdr}" 0 $(( padlength - ${#repo_hdr} )) "$pad" "| Branch" "| Version" " | Status"
echo ""
for product in "${REPOSITORIES[@]}"; do
  set_index $product
  branch=${REPO_BRANCHES[$current_idx]}
  status=${UPDATE_STATUS[$current_idx]}
  version=${VERSIONS[$current_idx]}
  printf '%s%*.*s%-20s%-20s%s\n' "$product" 0 $(( padlength - ${#product} )) "$pad" "| $branch" "| $version" " | $status"
done
printf "%0.s-" {1..120} && echo ""

