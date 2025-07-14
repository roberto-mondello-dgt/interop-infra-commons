#!/bin/bash
set -euo pipefail

PROJECT_DIR=${PROJECT_DIR:-$(pwd)}
ROOT_DIR=$PROJECT_DIR
SCRIPTS_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPTS_FOLDER"/common-functions.sh

help()
{
    echo "Usage:  [ -e | --environment ] Cluster environment used to execute kubectl diff
        [ -d | --debug ] Enable debug
        [ -m | --microservice ] Microservice defined in microservices folder
        [ -i | --image ] File with microservice image tag and digest
        [ -o | --output ] Default output to predefined dir. Otherwise set to "console" to print template output on terminal
        [ -sd | --skip-dep ] Skip Helm dependencies setup
        [ -dtl | --disable-templating-lookup ] Disable Helm --dry-run=server option in order to avoid lookup configmaps and secrets when templating
        [ -cp | --chart-path ] Path to Chart.yaml (default: ./Chart.yaml)
        [ -h | --help ] This help"
    exit 2
}

args=$#
environment=""
microservice=""
enable_debug=false
post_clean=false
output_redirect=""
skip_dep=false
disable_templating_lookup=false
images_file=""
chart_path=""

step=1
for (( i=0; i<$args; i+=$step ))
do
    case "$1" in
        -e| --environment )
            [[ "${2:-}" ]] || "Environment cannot be null" || help

          environment=$2
          step=2
          shift 2
          ;;
        -d | --debug)
          enable_debug=true
          step=1
          shift 1
          ;;
        -m | --microservice )
          [[ "${2:-}" ]] || "Microservice cannot be null" || help

          microservice=$2
          serviceAllowedRes=$(isAllowedMicroservice $microservice)
          if [[ -z $serviceAllowedRes || $serviceAllowedRes == "" ]]; then
            echo "$microservice is not allowed"
            echo "Allowed values: " $(getAllowedMicroservices)
            help
          fi

          step=2
          shift 2
          ;;
        -i | --image )
          images_file=$2

          step=2
          shift 2
          ;;
        -o | --output)
          [[ "${2:-}" ]] || "When specified, output cannot be null" || help
          output_redirect=$2
          if [[ $output_redirect != "console" ]]; then
            help
          fi

          step=2
          shift 2
          ;;
        -sd | --skip-dep)
          skip_dep=true
          step=1
          shift 1
          ;;
        -dtl | --disable-templating-lookup)
          disable_templating_lookup=true
          step=1
          shift 1
          ;;
        -h | --help )
          help
          ;;
        *)
          echo "Unexpected option: $1"
          help

          ;;
    esac
done

if [[ -z $environment || $environment == "" ]]; then
  echo "Environment cannot be null"
  help
fi
if [[ -z $microservice || $microservice == "" ]]; then
  echo "Microservice cannot be null"
  help
fi
if [[ $skip_dep == false ]]; then
  bash "$SCRIPTS_FOLDER"/helmDep.sh --untar
  skip_dep=true
fi

VALID_CONFIG=$(isMicroserviceEnvConfigValid $microservice $environment)
if [[ -z $VALID_CONFIG || $VALID_CONFIG == "" ]]; then
  echo "Environment configuration '$environment' not found for microservice '$microservice'"
  help
fi

ENV=$environment
OPTIONS=" "
if [[ $enable_debug == true ]]; then
  OPTIONS=$OPTIONS" -d"
fi
if [[ -n $output_redirect ]]; then
  OPTIONS=$OPTIONS" -o $output_redirect"
else
  OPTIONS=$OPTIONS" -o console "
fi
if [[ -n $images_file ]]; then
  OPTIONS=$OPTIONS" -i $images_file"
fi
if [[ $skip_dep == true ]]; then
  OPTIONS=$OPTIONS" -sd "
fi
if [[ $disable_templating_lookup != true ]]; then
  OPTIONS=$OPTIONS" --enable-templating-lookup "
fi

#HELM_TEMPLATE_CMD="$SCRIPTS_FOLDER/helmTemplate-svc-single.sh -e $ENV -m $microservice $OPTIONS"
#DIFF_CMD="KUBECTL_EXTERNAL_DIFF=$SCRIPTS_FOLDER/diff.sh kubectl diff --show-managed-fields=false -f -"
#eval $HELM_TEMPLATE_CMD" | "$DIFF_CMD

HELM_TEMPLATE_SCRIPT="$SCRIPTS_FOLDER/helmTemplate-svc-single.sh"
DIFF_SCRIPT="$SCRIPTS_FOLDER/diff.sh"

"$HELM_TEMPLATE_SCRIPT" -e "$ENV" -m "$microservice" $OPTIONS | \
 KUBECTL_EXTERNAL_DIFF="$DIFF_SCRIPT" kubectl diff --show-managed-fields=false -f -