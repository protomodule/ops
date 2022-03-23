#!/bin/bash
set -e

# Globals
HL='\033[0;34m\033[1m' # Highlight
ER='\033[0;31m'
NC='\033[0m' # No Color
APPLICATION=
ENVIRONMENT=
SYSTEM=

command -v aws >/dev/null 2>&1 || {
  echo -e "💥  ${WA}AWS CLI is not installed.$NC";
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo -e "💥  ${WA}jq CLI is not installed.$NC";
  exit 1
}

command -v git >/dev/null 2>&1 || {
  echo -e "💥  ${WA}git is not installed.$NC";
  exit 1
}

# Help
usage () {
    echo "usage: ./docker-aws.sh -a <APPLICATION> -e <ENVIRONMENT> -s <SYSTEM>" >&2
    echo >&2
    echo "Deploy a docker image to AWS using Protomodule AWS ASG / Secret Manager architecture." >&2
}

while getopts "ha:e:s:" flag; do
    case "${flag}" in
        h) usage; exit 0;;
        a) APPLICATION=$OPTARG;;
        e) ENVIRONMENT=$OPTARG;;
        s) SYSTEM=$OPTARG;;
        *) usage; exit 0;;
    esac
done

main () {
  # Checks
  if [ -z $AWS_DEFAULT_REGION ]; then echo -e "🛑   ${ER}AWS_DEFAULT_REGION${NC} is missing"; exit 1; fi
  if [ -z $AWS_ACCESS_KEY_ID ]; then echo -e "🛑   ${ER}AWS_ACCESS_KEY_ID${NC} is missing"; exit 1; fi
  if [ -z $AWS_SECRET_ACCESS_KEY ]; then echo -e "🛑   ${ER}AWS_SECRET_ACCESS_KEY${NC} is not specified"; exit 1; fi
  if [ -z $APPLICATION ]; then echo -e "🛑   No ${ER}APPLICATION${NC} specified"; exit 1; fi
  if [ -z $ENVIRONMENT ]; then echo -e "🛑   No ${ER}ENVIRONMENT${NC} specified"; exit 1; fi
  if [ -z $SYSTEM ]; then echo -e "🛑   No ${ER}SYSTEM${NC} specified"; exit 1; fi

  # Parse version number
  echo "ℹ️   Preparing version number"
  git fetch
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/protomodule/ops/main/helpers/generate-version.sh)" -- -s version
  source version.sh

  DEPLOY_TAG=$DOCKER_TAG
  if [ -z "$DEPLOY_TAG" ]; then
    DEPLOY_TAG=$LATEST_TAG
  fi

  RUNTIME_SECRET="$APPLICATION-runtime"
  
  echo ""
  echo -e "Runtime secret configuration:    $HL$RUNTIME_SECRET$NC"
  echo -e "System:                          $HL$SYSTEM$NC"
  echo -e "Environment:                     $HL$ENVIRONMENT$NC"
  echo -e "Version / tag:                   $HL$DEPLOY_TAG$NC"
  echo ""

  echo "🔧  Updating runtime configuration"
  SECRET_UPDATE=$(aws secretsmanager update-secret --secret-id "$RUNTIME_SECRET" --secret-string "$(aws secretsmanager get-secret-value --secret-id "$RUNTIME_SECRET" --query SecretString --output text | jq ".$ENVIRONMENT.$SYSTEM.deploy.docker_tag |= \"$DEPLOY_TAG\"" | jq ".$ENVIRONMENT.$SYSTEM.deploy.updated_at |= \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")")

  echo "🚀  Initiate EC2/ASG instance refresh for ASG '$APPLICATION-$ENVIRONMENT-$SYSTEM'"
  INSTANCE_REFRESH=$(aws autoscaling start-instance-refresh --auto-scaling-group-name "$APPLICATION-$ENVIRONMENT-$SYSTEM")

  echo "🏗  Running instance refresh '$(echo "$INSTANCE_REFRESH" | jq -r ".InstanceRefreshId")' in background"
  echo "👋  Done & Bye"
}

( cd . && main "$@" )
