#!/bin/bash
set -euo pipefail
echo ">>> helmDep.sh CALLED with args: $@"

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

function setupHelmDeps() {
    untar=$1

    echo "-- Helm dependencies setup started --"
    helm version --short

    TMP_CHART_DIR=$(mktemp -d)
    echo "Creating temp chart dir: $TMP_CHART_DIR"

    cp "$ROOT_DIR/Chart.yaml" "$TMP_CHART_DIR/"
    cp "$ROOT_DIR/Chart.lock" "$TMP_CHART_DIR/" 2>/dev/null || true
    mkdir -p "$TMP_CHART_DIR/charts"

    cd "$TMP_CHART_DIR"

    echo "-- Add PagoPA eks repos --"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null

    echo "-- Update PagoPA eks repos --"
    helm repo update > /dev/null

    if [[ $verbose == true ]]; then
        echo "-- Search PagoPA charts in repo --"
        helm search repo interop-eks-microservice-chart
        helm search repo interop-eks-cronjob-chart
    fi

    echo "-- Build chart dependencies --"
    helm dependency build --debug

    echo "-- List chart dependencies (after build) --"
    helm dependency list --debug | awk '{printf "%-35s %-15s %-20s\n", $1, $2, $3}'

    if [[ $untar == true ]]; then
        cd charts
        for filename in *.tgz; do 
            tar -xf "$filename" && rm -f "$filename"
        done
        cd ..
    fi

    set +e
    helm plugin install https://github.com/databus23/helm-diff
    diff_plugin_result=$?
    if [[ $verbose == true ]]; then
        echo "Helm-Diff plugin install result: $diff_plugin_result"
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}

setupHelmDeps $untar
