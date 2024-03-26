#!/bin/bash
set -e

# Globals
HL='\033[0;34m\033[1m' # Highlight
ER='\033[0;31m'
NC='\033[0m' # No Color
HEROKU_API_KEY=
HEROKU_APP_NAME=
HEROKU_DYNO=web
DOCKER_IMAGE=

command -v git >/dev/null 2>&1 || {
  echo -e "💥  ${WA}git is not installed.$NC";
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo -e "💥  ${WA}Docker is not installed.$NC";
  exit 1
}

command -v heroku >/dev/null 2>&1 || {
  echo -e "💥  ${WA}Heroku CLI is not installed.$NC";
  exit 1
}

# Help
usage () {
    echo "usage: ./docker-heroku.sh -k <HEROKU_API_KEY> -a <HEROKU_APP_NAME> -i <DOCKER_IMAGE>" >&2
    echo >&2
    echo "Deploy a docker image to Heroku." >&2
}

while getopts "hk:a:i:t:d:" flag; do
    case "${flag}" in
        h) usage; exit 0;;
        k) HEROKU_API_KEY=$OPTARG;;
        a) echo -e "🌍  Using Heroku app $HL${OPTARG}$NC" && HEROKU_APP_NAME=$OPTARG;;
        i) echo -e "🐳  Using Docker image $HL${OPTARG}$NC" && DOCKER_IMAGE=$OPTARG;;
        d) echo -e "🚀  Using $HL${OPTARG}$NC dyno" && HEROKU_DYNO=$OPTARG;;
        *) usage; exit 0;;
    esac
done

main () {
  # Checks
  if [ -z $HEROKU_API_KEY ]; then echo -e "🛑   ${ER}Heroku API key${NC} is missing"; exit 1; fi
  if [ -z $HEROKU_APP_NAME ]; then echo -e "🛑   ${ER}Heroku App name${NC} is not specified"; exit 1; fi
  if [ -z $DOCKER_IMAGE ]; then echo -e "🛑   No ${ER}Docker image${NC} specified"; exit 1; fi

  # Parse version number
  echo "ℹ️   Preparing version number"
  git fetch
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/protomodule/ops/main/helpers/generate-version.sh)" -- -s version
  source version.sh

  DEPLOY_TAG=$DOCKER_TAG
  if [ -z "$DEPLOY_TAG" ]; then
    DEPLOY_TAG=$LATEST_TAG
  fi
  
  echo ""
  echo -e "Deploying image:                  $HL$DOCKER_IMAGE$NC"
  echo -e "Tag:                              $HL$DEPLOY_TAG$NC"
  echo -e "Deploying to Heroku App:          $HL$HEROKU_APP_NAME$NC"
  echo -e "To Heroku Dyno:                   $HL$HEROKU_DYNO$NC"
  echo ""

  echo -e "🐳  Pulling $HL${HEROKU_DYNO}$NC image from registry"
  docker pull $DOCKER_IMAGE:$DEPLOY_TAG

  echo -e "🐳  Pushing $HL${HEROKU_DYNO}$NC image to Heroku"
  docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com
  docker tag $DOCKER_IMAGE:$DEPLOY_TAG registry.heroku.com/$HEROKU_APP_NAME/$HEROKU_DYNO
  docker push registry.heroku.com/$HEROKU_APP_NAME/$HEROKU_DYNO

  # Check if Procfile exists
  HEROKU_PROCESSES=""
  if [ -f "Procfile" ]; then
    echo -e "🥷  ${ER}Procfile${NC} detected. Setting up other processes.";

    # Iterate over processes in Procfile except the explicitly specified dyno
    grep -v "^$HEROKU_DYNO:" Procfile | cut -d':' -f 1 | while read PROC_NAME; do

      # Tag and push the image to Heroku
      echo -e "🐳  Pushing $HL${PROC_NAME}$NC image to Heroku"
      docker tag $DOCKER_IMAGE:$DEPLOY_TAG registry.heroku.com/$HEROKU_APP_NAME/$PROC_NAME
      docker push registry.heroku.com/$HEROKU_APP_NAME/$PROC_NAME

      # Add to process list for container release
      HEROKU_PROCESSES="${HEROKU_PROCESSES} $PROC_NAME"
    done
  fi

  echo -e "🚀  Releasing new version for $HL$HEROKU_DYNO$HEROKU_PROCESSES$NC"
  heroku container:release -a $HEROKU_APP_NAME $HEROKU_DYNO$HEROKU_PROCESSES

  echo ""
  echo "👋  Done & Bye"
}

( cd . && main "$@" )
