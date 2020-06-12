#!/bin/bash

OPTS=$1
OC_ENV_FILE=$2
GATEWAY_TYPE=$3
AWS_REGION=$4
ACCESS_KEY_ID=$5
SECRET_ACCESS_KEY=$6
OC_CERTS_FILE="/opt/opscruise/certs/server.cer.pem"

function help() {

      	echo "HELP:"
        # Help statements for only generating yamls
        echo "If you want to only generate the OpsCruise gateway yamls with this script and deploy manually, then please follow the given usage:"
        echo "Usage: $0 --only-generate-yaml <oc-environment.env-file-path> awsgw|k8sgw|promgw"
        echo "(Note: In case of awsgw, Usage: $0 --only-generate-yaml <oc-environment.env-file-path> awsgw <AWS_REGION>"
        echo ""
        # Help statements for automatically setup helmchart environment with this script
        echo "If you want to automatically setup OpsCruise helmchart environment with this script, then please follow the given usage:"
        echo "Usage: $0 --setup-helmchart-env <oc-environment.env_file_path> awsgw|k8sgw|promgw"
        echo "(Note: In case of awsgw, Usage: $0 --setup-helmchart-env <oc-environment_file_path> awsgw <AWS_REGION> <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY>)"
        echo ""
        # Help statements for automatically deploying gateways with this script
        echo "If you want to automatically deploy OpsCruise gateways with this script, then please follow the given usage:"
        echo "Usage: $0 --deploy <oc-environment.env_file_path> awsgw|k8sgw|promgw"
        echo "(Note: In case of awsgw, Usage: $0 --deploy <oc-environment_file_path> awsgw <AWS_REGION> <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY>)"
}

function create_namespace() {

	echo $(date -u) "Creating namespace"
  output=$((kubectl create namespace opscruise) 2>&1)
  if [[ $output == *"already exists"* ]]; then
    echo $(date -u) "Info from server: namespace 'opscruise' already exists"
  else
    echo $(date -u) $output
  fi

  output=$((kubectl create namespace collectors) 2>&1)
  if [[ $output == *"already exists"* ]]; then
    echo $(date -u) "Info from server: namespace 'collectors' already exists"
  else
    echo $(date -u) $output
  fi
}

function create_secret() {

	# create docker registry secret
	file=$OC_ENV_FILE
	while IFS="=" read -r key value; do
	case "$key" in
      		"DOCKER_SERVER") DOCKER_SERVER="$value" ;;
	        "DOCKER_USERNAME") DOCKER_USERNAME="$value" ;;
      		"DOCKER_PASSWORD") DOCKER_PASSWORD="$value" ;;
      		"DOCKER_EMAIL") DOCKER_EMAIL="$value"
	esac
	done < "$file"

  echo $(date -u) "Creating docker-registry oc-docker-creds secret"
  output=$((kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n opscruise) 2>&1)
  if [[ $output == *"already exists"* ]]; then
    echo $(date -u) "Info from server: docker-registry 'oc-docker-creds' secret already exists"
  else
    echo $(date -u) $output
  fi

	# create secret from supplied environment file
	echo $(date -u) "Creating generic oc-gw-creds secret"
  output=$((kubectl create secret generic oc-gw-creds --from-env-file=$OC_ENV_FILE -n opscruise) 2>&1)
  if [[ $output == *"already exists"* ]]; then
    echo $(date -u) "Info from server: generic 'oc-gw-creds' secret already exists"
  else
    echo $(date -u) $output
  fi

	# create secret of certs supplied by opscruise
	echo $(date -u) "Creating generic oc-gw-certs secret"
  output=$((kubectl create secret generic oc-gw-certs --from-file=$OC_CERTS_FILE -n opscruise) 2>&1)
  if [[ $output == *"already exists"* ]]; then
   echo $(date -u) "Info from server: generic 'oc-gw-certs' secret already exists"
 else
   echo $(date -u) $output
 fi
}

function run_k8sgw() {

	echo $(date -u) "Creating clusterrole for k8sgw"
  output=$((kubectl apply -f /opt/opscruise/k8sgw/clusterRole.yaml) 2>&1)
  echo $(date -u) $output

	echo $(date -u) "Creating deployment for k8sgw"
  output=$((kubectl apply -f /opt/opscruise/k8sgw/k8sgw.yaml) 2>&1)
  echo $(date -u) $output
}

function run_awsgw() {

  # create an awsgw yaml specific to region
  cp /opt/opscruise/awsgw/awsgw.yaml /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml
  sed -i "s/<AWS_REGION>/$AWS_REGION/g" /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml

  # create secret containing aws-access-key-id and secret-access-key with region
	echo $(date -u) "Creating generic oc-aws-credential secret"
  output=$((kubectl create secret generic oc-aws-credential --from-literal=AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID --from-literal=AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY -n opscruise) 2>&1)
  echo $(date -u) $output

	echo $(date -u) "Creating deployment for awsgw"
  output=$((kubectl apply -f /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml) 2>&1)
  echo $(date -u) $output
}

function run_promgw() {

	echo $(date -u) "Creating deployment for promgw"
  output=$((kubectl apply -f /opt/opscruise/promgw/promgw-deployment.yaml) 2>&1)
  echo $(date -u) $output

	echo $(date -u) "Creating service for promgw"
  output=$((kubectl apply -f /opt/opscruise/promgw/promgw-service.yaml) 2>&1)
  echo $(date -u) $output
}

function process() {

	case "$GATEWAY_TYPE" in

 	  k8sgw)
          run_k8sgw
          ;;
	  awsgw)
 		      run_awsgw
 		      ;;
	  promgw)
		      run_promgw
		      ;;
	  *)
		      echo "Wrong GATEWAY_TYPE"
		      help
		      exit 1
 	esac
}

function delete_gw_deployment() {

	# If any gateway deployment already exists, then delete the previous running deployment and create a new one
	case "$GATEWAY_TYPE" in

	  k8sgw)
		  kubectl delete -f /opt/opscruise/k8sgw/k8sgw.yaml &> /dev/null
		  ;;
	  awsgw)
		  kubectl delete secret oc-aws-credential -n opscruise &> /dev/null
		  kubectl delete -f /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml &> /dev/null
		  ;;
	  promgw)
		  kubectl delete -f /opt/opscruise/promgw/promgw-deployment.yaml &> /dev/null
		  kubectl delete -f /opt/opscruise/promgw/promgw-service.yaml &> /dev/null
		  ;;
	  *)
		  echo "Wrong GATEWAY_TYPE"
		  help
		  exit 1
	esac

}

function verify_deployment() {
        echo $(date -u) "Checking status of the deployment pod"
        sleep +30s

        case "$GATEWAY_TYPE" in
                k8sgw)
                        pod_name=$(kubectl get pod -n opscruise -o=custom-columns=NAME:.metadata.name | grep k8sgw-deployment)
                        pod_status=$(kubectl get pods $pod_name -n opscruise -o jsonpath="{.status.phase}")
                        ;;
                awsgw)
                        pod_name=$(kubectl get pod -n opscruise -o=custom-columns=NAME:.metadata.name | grep awsgw-deployment-$AWS_REGION)
                        pod_status=$(kubectl get pods $pod_name -n opscruise -o jsonpath="{.status.phase}")
                        ;;
                promgw)
                        pod_name=$(kubectl get pod -n opscruise -o=custom-columns=NAME:.metadata.name | grep promgw-deployment)
                        pod_status=$(kubectl get pods $pod_name -n opscruise -o jsonpath="{.status.phase}")
                        ;;
        esac
        if [ $pod_status = 'Running' ]; then
                echo $(date -u) "$GATEWAY_TYPE pod ($pod_name) is running successfully"
        else
                echo $(date -u) "$GATEWAY_TYPE pod ($pod_name) is NOT running successfully. Please check the logs using 'kubectl logs' command."
        fi
}

function generate_yaml() {
  if [ -z "$OC_ENV_FILE" ] || [ ! -f $OC_ENV_FILE ]; then
      echo $(date -u) "$OC_ENV_FILE: File not found. Please enter correct oc-environment.env path."
      help
      exit 1
  fi

  case "$GATEWAY_TYPE" in
        k8sgw)
                echo $(date -u) "k8sgw yamls generated at /opt/opscruise/k8sgw/"
                ;;
        awsgw)
                if [ -z $AWS_REGION ]; then
                  echo $(date -u) "Please enter AWS_REGION".
                  help
                  exit 1
                fi
                cp /opt/opscruise/awsgw/awsgw.yaml /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml
                sed -i "s/<AWS_REGION>/$AWS_REGION/g" /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml
                echo $(date -u) "awsgw yaml generated at /opt/opscruise/awsgw/"
                ;;
        promgw)
                echo $(date -u) "promgw yamls generated at /opt/opscruise/promgw/"
                ;;
        *)
		            echo $(date -u) "Empty or Wrong GATEWAY_TYPE"
		            help
		            exit 1
  esac
                gw_run_instructions
}

function gw_run_instructions() {
  file=$OC_ENV_FILE
        while IFS="=" read -r key value; do
        case "$key" in
                "DOCKER_SERVER") DOCKER_SERVER="$value" ;;
                "DOCKER_USERNAME") DOCKER_USERNAME="$value" ;;
                "DOCKER_PASSWORD") DOCKER_PASSWORD="$value" ;;
                "DOCKER_EMAIL") DOCKER_EMAIL="$value"
        esac
        done < "$file"

  case "$GATEWAY_TYPE" in
        k8sgw)
                echo "To run k8sgw, use the following commands:"
                echo "kubectl create namespace opscruise"
                echo "kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n opscruise"
                echo "kubectl create secret generic oc-gw-creds --from-env-file=$OC_ENV_FILE -n opscruise"
                echo "kubectl create secret generic oc-gw-certs --from-file=/opt/opscruise/certs/server.cer.pem -n opscruise"
                echo "kubectl apply -f /opt/opscruise/k8sgw/clusterRole.yaml"
                echo "kubectl apply -f /opt/opscruise/k8sgw/k8sgw.yaml"
                ;;
        awsgw)
                echo "To run awsgw, use the following commands:"
                echo "kubectl create namespace opscruise"
                echo "kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n opscruise"
		echo "kubectl create secret generic oc-gw-creds --from-env-file=$OC_ENV_FILE -n opscruise"
                echo "kubectl create secret generic oc-gw-certs --from-file=/opt/opscruise/certs/server.cer.pem -n opscruise"
                echo "kubectl create secret generic oc-aws-credential --from-literal=AWS_ACCESS_KEY_ID=<ACCESS_KEY_ID> --from-literal=AWS_SECRET_ACCESS_KEY=<SECRET_ACCESS_KEY> -n opscruise"
                echo "kubectl apply -f /opt/opscruise/awsgw/awsgw-$AWS_REGION.yaml"
                ;;
        promgw)
                echo "To run promgw, use the following commands:"
                echo "kubectl create namespace opscruise"
		echo "kubectl create secret docker-registry oc-docker-creds --docker-server=$DOCKER_SERVER --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n opscruise"
                echo "kubectl create secret generic oc-gw-creds --from-env-file=$OC_ENV_FILE -n opscruise"
                echo "kubectl create secret generic oc-gw-certs --from-file=/opt/opscruise/certs/server.cer.pem -n opscruise"
                echo "kubectl apply -f /opt/opscruise/promgw/promgw-deployment.yaml"
                echo "kubectl apply -f /opt/opscruise/promgw/promgw-service.yaml"
                ;;
  esac
}

function create_aws_secrets() {
  # create an helm values yaml specific to region
  cp /opt/opscruise/helmchart/helm-chart-awsgw/aws-values.yaml /opt/opscruise/helmchart/helm-chart-awsgw/values.yaml
  sed -i "s/<AWS_REGION>/$AWS_REGION/g" /opt/opscruise/helmchart/helm-chart-awsgw/values.yaml

  # create secret containing aws-access-key-id and secret-access-key with region
	echo $(date -u) "Creating generic oc-aws-credential secret"
  output=$((kubectl create secret generic oc-aws-credential --from-literal=AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID --from-literal=AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY -n opscruise) 2>&1)
  echo $(date -u) $output
}

function main {
  if [ $OPTS = "--setup-helmchart-env" ]; then
    if [ -z "$OC_ENV_FILE" ] || [ ! -f $OC_ENV_FILE ]; then
      echo $(date -u) "$OC_ENV_FILE: File not found. Please enter correct oc-environment.env path."
      exit 1
    fi
    if [ $GATEWAY_TYPE = "awsgw" ];
        then
          if [ -z "$AWS_REGION" ] || [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ]; then
            echo "Please enter AWS_REGION, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
            help
          exit 1
          fi
          create_aws_secrets
    fi
    create_namespace
    create_secret
  elif [ $OPTS = "--only-generate-yaml" ]; then
    generate_yaml
  elif [ $OPTS = "--deploy" ]; then
    if [ -z "$OC_ENV_FILE" ] || [ ! -f $OC_ENV_FILE ]; then
      echo $(date -u) "$OC_ENV_FILE: File not found. Please enter correct oc-environment.env path."
      exit 1
    fi
    if [ -z "$GATEWAY_TYPE" ]
    then
      echo "Please enter GATEWAY_TYPE"
      help
      exit 1
    fi
    if [ $GATEWAY_TYPE = "awsgw" ];
    then
            if [ -z "$AWS_REGION" ] || [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ]; then
              echo "Please enter AWS_REGION, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
              help
    	      exit 1
            fi
    fi
    delete_gw_deployment
    create_namespace
    create_secret
    process $GATEWAY_TYPE
    verify_deployment

  else
    echo "Wrong argument passed (Please use either '--only-generate-yaml' or '--deploy')"
    help
    exit 1
  fi
}

main
