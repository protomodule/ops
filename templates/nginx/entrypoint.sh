#!/usr/bin/env sh
set -e

# Define which nginx config template to use
## If a custom nginx template is included during the build process
## environment variable NGINX_TEMPLATE must point to the custom config file
##
## When environment variable FORCE_SSL is set to "yes" the nginx template
## is overwritten for safety reasons. Please inlcude SSL config in custom template
## when required.
NGINX_TEMPLATE=${NGINX_TEMPLATE:-/etc/nginx/conf.d/default.conf.template}
if [ "$FORCE_SSL" = "yes" ]; then
  echo "🔐  Force SSL (Redirect & HSTS)"
  NGINX_TEMPLATE=/etc/nginx/conf.d/forcessl.conf.template
fi

# Check $PORT or set fallback -> to be substituted in nginx config
if [ -z "$PORT" ]; then
  echo "🚨  Environment variable \$PORT not configured. Falling back to port 80"
  export PORT=80
fi
echo "🌍  Preparing nginx to listen on port $PORT"
envsubst '${PORT}' < "$NGINX_TEMPLATE" > /etc/nginx/conf.d/default.conf

# Setup basic auth when required
## To enable basic auth the environment variable NGINX_AUTH_PASS must be set
NGINX_AUTH_USER=${NGINX_AUTH_USER:-protected}
if [ -z "$NGINX_AUTH_PASS" ]; then
  echo "🔓  Starting publicly - no password protection"
else
  echo "🔐  Activating password protection"
  htpasswd -cbB /etc/nginx/htpasswd $NGINX_AUTH_USER $NGINX_AUTH_PASS
  MARKER="## ::AUTO-GENERATED::"
  CONFIG="auth_basic          \"Protected access\";\n  auth_basic_user_file \/etc\/nginx\/htpasswd;"
  sed -i "s/$MARKER/$CONFIG/g" "/etc/nginx/conf.d/default.conf"
fi

# Grab environment from infisical, first check if it is installed and if token is set otherwise skip
if [ -x "$(command -v infisical)" ] && [ -n "$INFISICAL_TOKEN" ]; then
  eval "$(infisical export --format=dotenv-export)"
fi

# Prepare public environment variables when NGINX_ENVJS_ENABLED is set to "yes"
## By default read all environment variables and write variables with prefix REACT_APP_
## to output file in JS notation (env.js) assigning all varibles into 'window.env'.
## Inlcude <script src="env.js"></script> into your index.html to load variables.
if [ "$NGINX_ENVJS_ENABLED" = "yes" ]; then
  NGINX_ENVJS_FILE=${NGINX_ENVJS_FILE:-./env.js}
  NGINX_ENVJS_PREFIX=${NGINX_ENVJS_PREFIX:-REACT_APP_}
  NGINX_ENVJS_TARGET=${NGINX_ENVJS_TARGET:-"window.env"}

  echo "💲  Preparing environment variables with prefix ${NGINX_ENVJS_PREFIX}*"
  # Recreate environment file
  rm -rf $NGINX_ENVJS_FILE
  touch $NGINX_ENVJS_FILE

  # Add assignment
  echo "$NGINX_ENVJS_TARGET = {" >> $NGINX_ENVJS_FILE

  # Read each line in environment
  # Each line represents key=value pairs
  printenv | grep "$NGINX_ENVJS_PREFIX" | while read line || [[ -n "$line" ]]; do
    # Split env variables by character `=`
    if printf '%s\n' "$line" | grep -q -e '='; then
      varname=$(printf '%s\n' "$line" | sed -e 's/=.*//')
      varvalue=$(printf '%s\n' "$line" | sed -e 's/^[^=]*=//')
    fi

    # Append configuration property to JS file
    echo "  $varname: \"$varvalue\"," >> $NGINX_ENVJS_FILE
  done

  echo "};" >> $NGINX_ENVJS_FILE
fi

exec "$@"
