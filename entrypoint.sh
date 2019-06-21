#!/bin/sh
set -eu
# this pulls in a list of all environment variables to pass into envsubst ${A}
ENV_PATTERN=$( env | awk -F = '{printf " ${%s}", $1}' )

# need to pass in pattern or envsubst will replace all $* strings
envsubst "${ENV_PATTERN}" < /etc/nginx/nginx.conf > /etc/nginx/conf.d/default.conf

exec "$@"
