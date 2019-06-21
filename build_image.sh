#!/usr/bin/env bash
set -x
# USAGE:  $1 = docker registry repository prefix - e.g. cypress, qa, etc.
#

# Registry -
#   A service responsible for hosting and distributing images. The default registry is the Docker Hub.
#
# Repository -
#   A collection of tags grouped under a common prefix (the name component before :).
#   For example, in an image tagged with the name my-app:3.1.4, my-app is the Repository component of the name.
#   A repository name is made up of slash-separated name components, optionally prefixed by the service's DNS hostname.
#   The hostname must follow comply with standard DNS rules, but may not contain _ characters.
#   If a hostname is present, it may optionally be followed by a port number in the format :8080.
#   Name components may contain lowercase characters, digits, and separators.
#   A separator is defined as a period, one or two underscores, or one or more dashes.
#   A name component may not start or end with a separator.
#
#
# Tag -
#   A tag serves to map a descriptive, user-given name to any single image ID.
#
# Image Name -
#   Informally, the name component after any prefixing hostnames and namespaces.

IMAGE_NAME=static-svelte-nginx
REPOSITORY_NAMESPACE=${1:-stevenacoffman}
# default REGISTRY is "hub.docker.com", so if you use something else, uncomment:
# REGISTRY="example.com"
# REPOSITORY="${REGISTRY}/${REPOSITORY_NAMESPACE}/${IMAGE_NAME}"

REPOSITORY="${REPOSITORY_NAMESPACE}/${IMAGE_NAME}"
# A docker tag name must be valid ASCII and may contain lowercase and uppercase letters,
# digits, underscores, periods and dashes.
# A docker tag name may not start with a period or a dash and may contain a maximum of 128 characters.
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's/[^\w.-]+//g')
GIT_REVISION=$(git rev-parse HEAD)
BUILD_TIME=$(date +'%s')

DIRECTORY="."

docker build --build-arg GIT_REVISION -t ${REPOSITORY} -t "${REPOSITORY}:${GIT_REVISION}" "${DIRECTORY}"
docker push ${REPOSITORY}
