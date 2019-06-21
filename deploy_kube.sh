#!/usr/bin/env bash
set -x

# USAGE:  $1 = docker registry repository prefix - e.g. cypress, qa, etc.
#         $2 = kubernetes namespace e.g. default, etc.
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

export APP_NAME="svelte-nginx"

echo "checking prerequisites:"
prerequisites=( kubectl docker git )
for i in "${prerequisites[@]}"
do
    if [ ! -x "$(command -v $i)" ]; then
        echo "$i not found. Try:"
        if [[ $i == *"docker"* ]]; then
          echo "brew cask install docker"
        else
          echo "brew install $i"
        fi
        exit 1
    fi
done


if (! docker stats --no-stream 2>/dev/null ); then
    # On Mac OS this would be the terminal command to launch Docker
    echo Docker is not running so starting
    open /Applications/Docker.app
    # Wait until Docker daemon is running and has completed initialisation
    while (! docker stats --no-stream 2>/dev/null ); do
      # Docker takes a few seconds to initialize
      echo "Waiting for Docker to launch..."
      sleep 1
    done
fi


GIT_REVISION="$(git rev-parse HEAD)"
IMAGE_NAME="${APP_NAME}"
REPOSITORY_NAMESPACE=${1:-stevenacoffman}
# default REGISTRY is "hub.docker.com", so if you use something else, uncomment:
# REGISTRY="example.com"
# REPOSITORY="${REGISTRY}/${REPOSITORY_NAMESPACE}/${IMAGE_NAME}"
REPOSITORY="${REPOSITORY_NAMESPACE}/${IMAGE_NAME}"

if output="$(git status --porcelain)" && [ -z "$output" ]; then
  echo "Git working directory is clean."
  # Working directory clean

  echo "Building docker image"

  DIRECTORY="."

  docker build --build-arg GIT_REVISION -t ${REPOSITORY} -t "${REPOSITORY}:${GIT_REVISION}" "${DIRECTORY}"

  echo pushing
  docker push "${REPOSITORY}"
else
  echo "There are Uncommitted changes. Please commit and try again"
  exit 1
fi

KUBERNETES_NAMESPACE=${2:-default}
echo "Deploying to kubernetes namespace ${KUBERNETES_NAMESPACE} using image ${REPOSITORY}:${GIT_REVISION}"

mkdir -p ./k8s
tee "./k8s/${APP_NAME}.yaml" <<EOF >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${KUBERNETES_NAMESPACE}
  labels:
    app: ${APP_NAME}
    git: "${GIT_REVISION}"
spec:
  replicas: 3 # tells deployment to run 3 pods
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels: # tell deployment which pod to update, should match pod template labels
      app: ${APP_NAME}
  template: # create pods using pod definition in this template
    metadata:
      labels:
        app: ${APP_NAME}
        git: "${GIT_REVISION}"
    spec:
      restartPolicy: Always
      containers:
      - name: ${APP_NAME}
        image: ${REPOSITORY}:${GIT_REVISION}
#        tty: true
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: THIS_INSTANCE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: THIS_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: PROMETHEUS_PORT
          value: "9113"
        readinessProbe:
          httpGet:
            path: /
            port: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
        resources:
          requests:
            cpu: 100m
            memory: 300Mi
          limits:
            # This limit was intentionally set low as a reminder that
            # it is meant to be tweaked
            # before you run production workloads
            memory: 600Mi
      - name: metrics
        image: nginx/nginx-prometheus-exporter:0.4.0
        imagePullPolicy: IfNotPresent
        command: [ '/usr/bin/exporter']
        env:
        - name: SCRAPE_URI
          value: 'http://127.0.0.1:8080/nginx_status/'
        - name: NGINX_RETRIES
          value: '10'
        - name: TELEMETRY_PATH
          value: '/metrics'
        ports:
        - name: metrics
          containerPort: 9113
        livenessProbe:
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 15
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 5
          timeoutSeconds: 1
EOF

kubectl apply -f "./k8s/${APP_NAME}.yaml"
