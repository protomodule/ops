#!/bin/bash
# set -e

# Globals
HL='\033[0;34m\033[1m' # Highlight
WA='\033[0;33m\033[1m' # Warning
ER='\033[0;31m'
NC='\033[0m' # No Color
WATCH_URL=
WATCH_VERSION=
WATCH_TIMEOUT=300
PID=$$
COUNT=1

command -v curl >/dev/null 2>&1 || {
  echo -e "š„  ${WA}curl is not installed.$NC";
  exit 1
}

# Help
usage () {
    echo "usage: ./watch-update.sh -u <URL> -v <EXPECTED_VERSION> -t <TIMEOUT_SECONDS>" >&2
    echo >&2
    echo "Periodically poll URL and check if version changed successfully." >&2
}

while getopts "hu:v:t:" flag; do
    case "${flag}" in
        h) usage; exit 0;;
        u) WATCH_URL=$OPTARG;;
        v) WATCH_VERSION=$OPTARG;;
        t) WATCH_TIMEOUT=$OPTARG;;
        *) usage; exit 0;;
    esac
done

main () {
  # Checks
  if [ -z $WATCH_URL ]; then echo -e "š   No ${ER}URL${NC} specified (-u argument)"; exit 1; fi
  if [ -z $WATCH_VERSION ]; then echo -e "š   No ${ER}expected version${NC} specified (-v argument)"; exit 1; fi


  echo "š  Checking version periodically"
  START=$(date +%s)
  LAST_VERSION=
  while [[ $(($(date +%s) - $START)) -lt $WATCH_TIMEOUT ]]
  do
    CURRENT_VERSION=$(curl -s $WATCH_URL)
    EXIT_CODE=$?

    if [ "$EXIT_CODE" != "0" ]; then
      echo "š„ [$(date -u +"%Y-%m-%dT%H:%M:%SZ") / NĀ°$COUNT]: App offline"
      # exit $EXIT_CODE
    elif [[ $CURRENT_VERSION =~ "<" ]]; then
      echo "ā [$(date -u +"%Y-%m-%dT%H:%M:%SZ") / NĀ°$COUNT]: Response invalid"
    else
      if [ "$CURRENT_VERSION" == "$WATCH_VERSION" ]; then
        echo -e "š¢  New version is ${HL}$CURRENT_VERSION$NC online."
        exit 0
      fi

      if [ "$LAST_VERSION" == "" ]; then
        echo -e "š·   Current version: $WA$CURRENT_VERSION$NC --> Expected version: $HL$WATCH_VERSION$NC"
      else
        echo "š  [$(date -u +"%Y-%m-%dT%H:%M:%SZ") / NĀ°$COUNT]: No change"
      fi
      LAST_VERSION=$CURRENT_VERSION
    fi

    COUNT=$(($COUNT + 1))
    sleep 3
  done

  echo "ā°  Deployment did not finish within timeout - consider deployment as failed!"
  exit 1
}

( cd . && main "$@" )
