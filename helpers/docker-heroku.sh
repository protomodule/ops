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

  echo "🐳  Pulling image from registry"
  docker pull $DOCKER_IMAGE:$DEPLOY_TAG

  echo "🐳  Pushing image to Heroku"
  docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com
  docker tag $DOCKER_IMAGE:$DEPLOY_TAG registry.heroku.com/$HEROKU_APP_NAME/$HEROKU_DYNO
  docker push registry.heroku.com/$HEROKU_APP_NAME/$HEROKU_DYNO

  echo "🚀  Releasing new version"
  heroku container:release -a $HEROKU_APP_NAME $HEROKU_DYNO

  echo ""
  echo "👋  Done & Bye"
}

( cd . && main "$@" )
