#!/bin/bash

OC_ENV_FILE=$1

DOCKER_SERVER=""
DOCKER_USERNAME=""
DOCKER_PASSWORD=""
DOCKER_EMAIL=""
OC_CERTS_FILE="/opt/opscruise/certs/server.cer.pem"
PROJECT_DIR="/opt/opscruise"

function create_namespace() {

  kubectl create namespace opscruise &> /dev/null
  kubectl create namespace collectors &> /dev/null
}

function create_secret() {

  kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n opscruise
  kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n kube-system

  kubectl create secret generic oc-gw-creds --from-env-file=$OC_ENV_FILE -n opscruise
  kubectl create secret generic oc-gw-certs --from-file=$OC_CERTS_FILE -n opscruise
}

function run_prometheus+promgw() {

  kubectl apply -f $PROJECT_DIR/collectors/cadvisor
  kubectl apply -f $PROJECT_DIR/collectors/KSM
  kubectl apply -f $PROJECT_DIR/collectors/node-exporter
  kubectl apply -f $PROJECT_DIR/collectors/promgw
}

function help() {

  echo "Usage: $0 <OC-ENVIRONMENT.env>"
}

function main() {

  if [ -z "$OC_ENV_FILE" ] || [ ! -f $OC_ENV_FILE ]; then
    echo "$OC_ENV_FILE: File not found. Please enter correct oc-environment.env path."
    help
    exit 1
  fi

  file=$OC_ENV_FILE
    while IFS="=" read -r key value; do
    case "$key" in
      "DOCKER_SERVER") DOCKER_SERVER="$value" ;;
      "DOCKER_USERNAME") DOCKER_USERNAME="$value" ;;
      "DOCKER_PASSWORD") DOCKER_PASSWORD="$value" ;;
      "DOCKER_EMAIL") DOCKER_EMAIL="$value"
    esac
    done < "$file"

  create_namespace
  create_secret
  run_prometheus+promgw
}

main