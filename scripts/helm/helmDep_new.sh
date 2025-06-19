#!/bin/bash
set -euo pipefail

help()
{
    echo "Usage: 
        [ -u | --untar ] Untar downloaded charts
        [ -v | --verbose ] Show debug messages
        [ -h | --help ] This help" 
    exit 2
}

PROJECT_DIR=${PROJECT_DIR:-$(pwd)}
ROOT_DIR=$PROJECT_DIR
SCRIPTS_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

args=$#
untar=false
step=1
verbose=false

for (( i=0; i<$args; i+=$step ))
do
    case "$1" in
        -u| --untar )
          untar=true
          step=1
          shift 1
          ;;
        -v| --verbose )
          verbose=true
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

function setupHelmDeps() 
{
    untar=$1

    echo "# Helm dependencies setup #"
    echo "-- Add PagoPA eks repos --"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null

    echo "-- Update PagoPA eks repo --"
    helm repo update interop-eks-microservice-chart > /dev/null
    helm repo update interop-eks-cronjob-chart > /dev/null

    CHARTS=(
      "$ROOT_DIR/charts/interop-eks-microservice-chart"
      "$ROOT_DIR/charts/interop-eks-cronjob-chart"
    )

    for CHART_DIR in "${CHARTS[@]}"; do
        if [[ -f "$CHART_DIR/Chart.yaml" ]]; then
            echo "⎈ Handling dependencies for: $CHART_DIR"
            
            if [[ $verbose == true ]]; then
                echo "-- List chart dependencies for $CHART_DIR --"
                helm dep list "$CHART_DIR" | awk '{printf "%-35s %-15s %-20s\n", $1, $2, $3}'
            fi
            
            dep_up_result=$(helm dep up "$CHART_DIR")

            if [[ $verbose == true ]]; then
                echo "$dep_up_result"
            fi

            if [[ $untar == true ]]; then
                if [[ -d "$CHART_DIR/charts" ]]; then
                    cd "$CHART_DIR/charts"
                    for filename in *.tgz; do
                        [ -f "$filename" ] && tar -xf "$filename" && rm -f "$filename"
                    done
                    cd "$CHART_DIR"
                fi
            fi
        else
            echo "⚠️  Skipping $CHART_DIR: Chart.yaml not found."
        fi
    done

    set +e
    # Install helm diff plugin
    helm plugin list | grep -q diff || helm plugin install https://github.com/databus23/helm-diff
    diff_plugin_result=$?
    if [[ $verbose == true ]]; then
        echo "Helm-Diff plugin install result: $diff_plugin_result"
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}


setupHelmDeps $untar