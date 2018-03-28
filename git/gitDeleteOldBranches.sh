#!/bin/bash

## ============================================================================
## Deletes a set of old branches (locally and remote) using a file of prepared tags
##
## This is a paranoid deletion so it requires the following:
## > -y | --year Specify the year (defaulted to 2017)
## > -m | --month Specify the month)
## > Cannot delete current month's branches (only older)
## > Specific exclusions of master/develop/hotfix/release and HEAD branches/refs
## > Only specific inclusions of feature or bugfix allowed 
## > Only merged or non-merged branches can be deleted in a single run
## Usage: Try a query first before deleting, e.g.
## >gitDeleteOldBranches.sh --merged true -m 02 -y 2018 -b feature
## >gitDeleteOldBranches.sh --merged true -m 02 -y 2018 -b feature --delete
## >gitDeleteOldBranches.sh --merged false -m 02 -y 2018 -b bugfix
## >gitDeleteOldBranches.sh --merged false -m 02 -y 2018 -b bugfix --delete
## ============================================================================

YEAR_TO_DELETE=2017
MONTH_TO_DELETE=
INCLUDE_MERGED_ONLY=true
DELETE=false
BRANCH_TYPE=feature
OVERRIDE_CURRENT_MONTH=false

function usage {
echo "usage: gitDeleteOldBranches.sh"
  echo "  Parameters:"
  echo "  -y | --year           : year to filter deletions"
  echo "  -m | --month          : month to filter deletions"
  echo "  -b | --branch-type    : branch type to filter deletions [ feature | bugfix ]"
  echo "  --merged [true|false] : include/exclude merged branches (merged=true is default)"
  echo "  --delete              : force deletion of selected branches (otherwise display only)"
  echo "  -h | --help           : Show this usage message"
}

#Process command line parameters
while [ "$1" != "" ]; do
  case $1 in
  	-y | --year )
	    shift
	    YEAR_TO_DELETE=$1
	    ;;
	-m | --month )
	    shift
	    MONTH_TO_DELETE=$1
	    ;;
    -b | --branch-type )
	    shift
	    BRANCH_TYPE=$1
	    ;;
	--merged )
	    shift
	    INCLUDE_MERGED_ONLY=$1
	    ;;	 
	--delete )
	    shift
	    DELETE=true
	    ;;
    --override-current-month )
	    shift
	    OVERRIDE_CURRENT_MONTH=$1
	    ;;
    -h | --help )
        usage
        exit
        ;;
    * )
        usage
        exit 1
  esac
  shift
done

if [ "x$MONTH_TO_DELETE" == "x" ]; then
  echo "ERROR: YYYY-MM is required to filter the branches. Month was not specified. Use -m | --month [month] to select the month. There is no default."
  exit 1
fi

current_year=$(date "+%Y")
current_month=$(date "+%m")
current_numeric_month=$current_month
if [ ${current_month:0:1} == 0 ]; then
	current_numeric_month=${current_month:1:1}
fi
filter_numeric_month=$MONTH_TO_DELETE
if [ ${MONTH_TO_DELETE:0:1} == 0 ]; then
	filter_numeric_month=${MONTH_TO_DELETE:1:1}
fi
if [ ${#MONTH_TO_DELETE} -eq 1 ]; then
	MONTH_TO_DELETE="0${MONTH_TO_DELETE}"
fi

merged="--merged"
if [ ! $INCLUDE_MERGED_ONLY == "true" ]; then
  merged=""
fi

date_filter="$YEAR_TO_DELETE-$MONTH_TO_DELETE"

echo "Input parameters to delete branches"
echo "-----------------------------------"
echo "YEAR_TO_DELETE=$YEAR_TO_DELETE"
echo "MONTH_TO_DELETE=$MONTH_TO_DELETE"
echo "current_year=$current_year"
echo "current_month=$current_month"
echo "date_filter=$date_filter"
echo "filter_numeric_month=$filter_numeric_month"
echo "current_numeric_month=$current_numeric_month"
echo "BRANCH_TYPE=$BRANCH_TYPE"
echo "INCLUDE_MERGED_ONLY=$INCLUDE_MERGED_ONLY"
echo "merged=$merged"
echo "delete=$DELETE"
echo ""

if [  ${#YEAR_TO_DELETE} -ne 4 ]; then  
	echo "ERROR: The specified year [$YEAR_TO_DELETE] is invalid and must be 4 digits (YYYY)"
	exit 10
fi

if [ "$YEAR_TO_DELETE" == "$current_year" -a "$filter_numeric_month" == "$current_numeric_month" ]; then
	if [ ! "$OVERRIDE_CURRENT_MONTH" == "true" -o "$INCLUDE_MERGED_ONLY" == "false" ]; then
  	  echo "ERROR: Cannot batch-delete the current or current month's branches"
	  exit 10
    fi
fi

if [ ! $BRANCH_TYPE == "feature" -a ! $BRANCH_TYPE == "bugfix" ]; then
	echo "ERROR: Only the following branch types are allowed for batch deletion: [ feature | bugfix ]"
	exit 20
fi
 
branch_file="branches_to_delete"

git for-each-ref \
  --sort=-committerdate refs/remotes/ \
  --format='%(authordate:short) %(color:red)%(objectname:short) %(color:yellow)%(refname:short)%(color:reset) (%(color:green)%(committerdate:relative)%(color:reset))' \
  $merged \
  | grep -v "origin/master" \
  | grep -v "origin/HEAD" \
  | grep -v "origin/develop" \
  | grep -v "origin/hotfix" \
  | grep -v "origin/release" \
  | grep "origin/${BRANCH_TYPE}" \
  | grep $date_filter \
  > $branch_file

if [ ! -f $branch_file ]; then
  echo "ERROR: The file [$branch_file] does not exist."
  exit 2
fi

branches_to_delete=$(cat $branch_file | wc -l)
branches_to_delete="${branches_to_delete#"${branches_to_delete%%[![:space:]]*}"}"
echo ""
echo "Branches to delete"
echo "------------------"
cat $branch_file
echo ""
echo "Total: $(cat $branch_file | wc -l)"

if [ $DELETE == "false" ]; then
	exit 0
fi

branches_deleted=0

while read branch_entry; do
  ignore="false"
  branch=$(echo $branch_entry | cut -d ' ' -f3)
  branch=${branch#*/}
  branch=${branch%*/}
  
  #security override to protect any master or develop branch
  if [ "$branch" == *"master"* -o "$branch" == *"develop"* ]; then
    echo "master or develop branch found - ignoring"
    ignore="true"
  fi
  if [ "$ignore" = "false" ]; then
    echo "Deleting branch [$branch]"
	git push origin --delete $branch
	if [ $? -eq 0 ]; then
	  branches_deleted=$((branches_deleted+1))
	fi
  fi
done < $branch_file

rm $branch_file

echo "Branches deleted $branches_deleted/$branches_to_delete"
  