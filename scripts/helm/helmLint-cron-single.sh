#!/bin/bash
set -euo pipefail

PROJECT_DIR=${PROJECT_DIR:-$(pwd)}
ROOT_DIR=$PROJECT_DIR
SCRIPTS_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPTS_FOLDER"/common-functions.sh

help()
{
    echo "Usage:  [ -e | --environment ] Environment used to detect values.yaml for linting
        [ -d | --debug ] Enable Helm template debug
        [ -j | --job ] Cronjob defined in jobs folder
        [ -i | --image ] File with cronjob image tag and digest
        [ -o | --output ] Default output to predefined dir. Otherwise set to "console" to print linting output on terminal
        [ -c | --clean ] Clean files and directories after script successfull execution
        [ -sd | --skip-dep ] Skip Helm dependencies setup
        [ -cp | --chart-path ] Path to Chart.yaml file (overrides environment selection; must be an existing file)
        [ -h | --help ] This help"
    exit 2
}

args=$#
environment=""
job=""
enable_debug=false
post_clean=false
output_redirect=""
skip_dep=false
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
        -d | --debug)
          enable_debug=true
          step=1
          shift 1
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
        -c | --clean)
          post_clean=true
          step=1
          shift 1
          ;;
        -sd | --skip-dep)
          skip_dep=true
          step=1
          shift 1
          ;;
        -cp | --chart-path )
          [[ "${2:-}" ]] || { echo "Error: The chart path (-cp/--chart-path) cannot be null or empty."; help; }
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
  echo "Environment cannot be null"
  help
fi
if [[ -z $job || $job == "" ]]; then
  echo "Job cannot be null"
  help
fi
if [[ $skip_dep == false ]]; then
  bash "$SCRIPTS_FOLDER"/helmDep.sh --untar --chart-path "$resolved_chart_path" --environment "$environment"
fi

VALID_CONFIG=$(isCronjobEnvConfigValid $job $environment)
if [[ -z $VALID_CONFIG || $VALID_CONFIG == "" ]]; then
  echo "Environment configuration '$environment' not found for cronjob '$job'"
  help
fi

ENV=$environment
JOB_DIR=$( echo $job | sed  's/-/_/g' )
OUT_DIR="$ROOT_DIR/out/lint/$ENV/job_$JOB_DIR"
if [[ $output_redirect != "console" ]]; then
  rm -rf "$OUT_DIR"
  mkdir  -p "$OUT_DIR"
else
  OUT_DIR=""
fi

IMAGE_VERSION_READER_OPTIONS=""
if [[ -n $images_file ]]; then
  IMAGE_VERSION_READER_OPTIONS=" -f $images_file"
fi

# Find image version and digest
bash "$SCRIPTS_FOLDER"/image-version-reader-v2.sh -e $environment -j $job $IMAGE_VERSION_READER_OPTIONS

LINT_CMD="helm lint"
if [[ $enable_debug == true ]]; then
  LINT_CMD+=" --debug"
fi

OUTPUT_TO="> \"$OUT_DIR/$job.out.yaml\""
if [[ $output_redirect == "console" ]]; then
  OUTPUT_TO=""
fi
#LINT_CMD=$LINT_CMD" \"$ROOT_DIR/charts/interop-eks-cronjob-chart\" -f \"$ROOT_DIR/charts/interop-eks-cronjob-chart/values.yaml\" -f \"$ROOT_DIR/commons/$ENV/values-cronjob.compiled.yaml\" -f \"$ROOT_DIR/jobs/$job/$ENV/values.yaml\" $OUTPUT_TO"

LINT_CMD+=" \"$ROOT_DIR/charts/interop-eks-cronjob-chart\""
LINT_CMD+=" -f \"$ROOT_DIR/charts/interop-eks-cronjob-chart/values.yaml\""
LINT_CMD+=" -f \"$ROOT_DIR/commons/$ENV/values-cronjob.compiled.yaml\""
LINT_CMD+=" -f \"$ROOT_DIR/jobs/$job/$ENV/values.yaml\""
LINT_CMD+=" $OUTPUT_TO"

eval $LINT_CMD

if [[ $output_redirect != "console" && $post_clean == true ]]; then
  rm -rf $OUT_DIR
fi
