#!/bin/bash
set -euo pipefail

PROJECT_DIR=${PROJECT_DIR:-$(pwd)}
ROOT_DIR=$PROJECT_DIR
SCRIPTS_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPTS_FOLDER"/common-functions.sh

help()
{
    echo "Usage:  [ -e | --environment ] Cluster environment used to execute helm upgrade
        [ -dr | --dry-run ] Enable dry-run mode
        [ -d | --debug ] Enable debug
        [ -a | --atomic ] Enable helm install atomic option
        [ -j | --job ] Cronjob defined in jobs folder
        [ -i | --image ] File with cronjob image tag and digest
        [ -o | --output ] Default output to predefined dir. Otherwise set to "console" to print template output on terminal or "null" to redirect output to /dev/null
        [ -sd | --skip-dep ] Skip Helm dependencies setup
        [ -hm | --history-max ] Set the maximum number of revisions saved per release
        [ --force ] Force helm upgrade
        [ -cp | --chart-path ] Path to Chart.yaml (default: ./Chart.yaml)
        [ -h | --help ] This help"
    exit 2
}

args=$#
environment=""
job=""
enable_atomic=false
enable_debug=false
enable_dryrun=false
post_clean=false
output_redirect=""
skip_dep=false
images_file=""
force=false
history_max=3
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
        -a | --atomic)
          enable_atomic=true
          step=1
          shift 1
          ;;
        -d | --debug)
          enable_debug=true
          step=1
          shift 1
          ;;
        -dr | --dry-run)
          enable_dryrun=true
          step=1
          shift 1
          ;;
        -j | --job )
          [[ "${2:-}" ]] || "Job cannot be null" || help

          job=$2
          jobAllowedRes=$(isAllowedCronjob $job)
          if [[ -z $jobAllowedRes || $jobAllowedRes == "" ]]; then
              echo "$job is not allowed"
              echo "Allowed values: " $(getAllowedCronjobs)
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
          if [[ $output_redirect != "console" && $output_redirect != "null" ]]; then
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
        -hm | --history-max )
          [[ "${2:-}" ]] || "When specified, history-max cannot be null" || help
          history_max=$2
          if [[ $history_max -lt 0 ]]; then
            echo "History-max must be equal or greater than 0"
            help
          fi

          step=2
          shift 2
          ;;
        --force)
          force=true
          step=1
          shift 1
          ;;
        -cp | --chart-path )
          chart_path=$2
          step=2
          shift 2
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
  echo "[CRONJOB-UPGRADE] Environment cannot be null"
  help
fi
if [[ -z $job || $job == "" ]]; then
  echo "[CRONJOB-UPGRADE] Job cannot null"
  help
fi
if [[ $skip_dep == false ]]; then
  bash "$SCRIPTS_FOLDER"/helmDep.sh --untar --verbose --chart-path "$chart_path"
  skip_dep=true
fi

VALID_CONFIG=$(isCronjobEnvConfigValid $job $environment)
if [[ -z $VALID_CONFIG || $VALID_CONFIG == "" ]]; then
  echo "[CRONJOB-UPGRADE] Environment configuration '$environment' not found for cronjob '$job'"
  help
fi

ENV=$environment
OPTIONS=" "
if [[ $enable_atomic == true ]]; then
  OPTIONS=$OPTIONS" --atomic"
fi
if [[ $enable_debug == true ]]; then
  OPTIONS=$OPTIONS" --debug"
fi
if [[ $enable_dryrun == true ]]; then
  OPTIONS=$OPTIONS" --dry-run"
fi
if [[ $force == true ]]; then
  OPTIONS=$OPTIONS" --force"
fi

OUTPUT_REDIRECT=" "
if [[ -n $output_redirect && $output_redirect == "null" ]]; then
  OUTPUT_REDIRECT=$OUTPUT_REDIRECT" >/dev/null"
fi

# START - Find image version and digest
IMAGE_VERSION_READER_OPTIONS=""
if [[ -n $images_file ]]; then
  IMAGE_VERSION_READER_OPTIONS=" -f $images_file"
fi

echo "[CRONOJB-UPGRADE] Computing image version and digest for cronjob '$job'."
. "$SCRIPTS_FOLDER"/image-version-reader-v2.sh -e $environment -j $job $IMAGE_VERSION_READER_OPTIONS
# END - Find image version and digest

UPGRADE_CMD="helm upgrade "
UPGRADE_CMD="$UPGRADE_CMD --dependency-update --take-ownership --create-namespace --history-max $history_max "
UPGRADE_CMD="$UPGRADE_CMD $OPTIONS "
UPGRADE_CMD="$UPGRADE_CMD --namespace $ENV "
UPGRADE_CMD="$UPGRADE_CMD --install $job \"$ROOT_DIR/charts/interop-eks-cronjob-chart\" "
UPGRADE_CMD="$UPGRADE_CMD -f \"$ROOT_DIR/commons/$ENV/values-cronjob.compiled.yaml\" "
UPGRADE_CMD="$UPGRADE_CMD -f \"$ROOT_DIR/jobs/$job/$ENV/values.yaml\" "
UPGRADE_CMD="$UPGRADE_CMD $OUTPUT_REDIRECT"

echo "[CRONJOB-UPGRADE] Executing $job upgrade command."
eval $UPGRADE_CMD
