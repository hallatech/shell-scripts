#!/bin/bash

## ============================================================================
## Bamboo check for valid deployment tag parameter from which to run job
## ============================================================================

if [ "${bamboo_DEV_DEPLOYMENT_TAG}" = "" ]; then
  echo "Failing deployment because required DEV_DEPLOYMENT_TAG is not set."
  exit 1
else
  echo "Plan can execute with supplied DEV_DEPLOYMENT_TAG=${bamboo_DEV_DEPLOYMENT_TAG}"
fi