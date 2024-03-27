#!/usr/bin/env sh

#  _    _                _          
# | |  | |              | |         
# | |__| | ___ _ __ ___ | | ___   _ 
# |  __  |/ _ \ '__/ _ \| |/ / | | |
# | |  | |  __/ | | (_) |   <| |_| |
# |_|  |_|\___|_|  \___/|_|\_\\__,_|
#
#      E N T R Y P O I N T

# This script is used as entrypoint for containers running on Heroku.
# It decides on startup to run container as web or worker as defined in the Procfile.
# Requires a Procfile to be present in the root of the project.

# Exit immediately if a command exits with a non-zero status
set -e
HL='\033[0;34m\033[1m'; ER='\033[0;31m'; NC='\033[0m'

# Only run start the container if no arguments are passed
if [ -z "$@" ]; then

  # Check if Procfile exists
  if ! [ -f "Procfile" ]; then echo "🛑  ${ER}Procfile${NC} is missing. Add it to the Dockerfile."; exit 1; fi

  # Get the process type from the DYNO environment variable
  PROC_NAME="$(echo "$DYNO" | cut -d'.' -f 1)"
  PROC_NAME=${PROC_NAME:-web}
  echo "🐳  Using process $HL${PROC_NAME}$NC from Procfile"

  # Get the command for the process type from the Procfile
  PROC_CMD=$(grep "^$PROC_NAME:" Procfile | sed 's/:/|/' | cut -d'|' -f 2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n')
  if [ -z "$PROC_CMD" ]; then echo -e "💥  No command for ${WA}$PROC_NAME$NC found. Exiting now!"; exit 1; fi

  # Run the command
  echo "🚀  Running $HL${PROC_CMD}$NC"
  echo ""
  exec $PROC_CMD
fi

# --- Fallback ---

# Run command with node if the first argument contains a "-" or is not a system command. The last
# part inside the "{}" is a workaround for the following bug in ash/dash:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=874264
if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
  set -- node "$@"
fi

exec "$@"
