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
[[ -f "$ROOT_DIR/Chart.yaml" ]] || ROOT_DIR="$PROJECT_DIR/chart"
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
    local untar=$1

    cd "$ROOT_DIR"

    rm -rf charts
    mkdir -p charts

    # Copia Chart.yaml temporaneamente in charts/
    cp Chart.yaml charts/

    echo "# Helm dependencies setup #"
    echo "-- Add PagoPA eks repos --"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null

    echo "-- Update PagoPA eks repo --"
    helm repo update interop-eks-microservice-chart > /dev/null
    helm repo update interop-eks-cronjob-chart > /dev/null

    if [[ $verbose == true ]]; then
        echo "-- Search PagoPA charts in repo --"
        helm search repo interop-eks-microservice-chart
        helm search repo interop-eks-cronjob-chart
    else
        helm search repo interop-eks-microservice-chart > /dev/null
        helm search repo interop-eks-cronjob-chart > /dev/null
    fi

    echo "-- Build chart dependencies --"
    cd charts

    if [[ $verbose == true ]]; then
        helm dep list | awk '{printf "%-35s %-15s %-20s\n", $1, $2, $3}'
    fi

    dep_up_result=$(helm dep build)
    if [[ $verbose == true ]]; then
        echo "$dep_up_result"
    fi

    if [[ $untar == true ]]; then
        if compgen -G "*.tgz" > /dev/null; then
            for filename in *.tgz; do 
                dirname=$(basename "$filename" .tgz)
                rm -rf "$dirname"
                mkdir -p "$dirname"
                tar -xzf "$filename" -C "$dirname" --strip-components=1
                rm -f "$filename"
        fi
    fi

    # Pulizia temporanea
    rm -f Chart.yaml
    cd ..

    set +e
    if ! helm plugin list | grep -q "diff"; then
        helm plugin install https://github.com/databus23/helm-diff
        diff_plugin_result=$?
    else
        diff_plugin_result=0
    fi
    if [[ $verbose == true ]]; then
        echo "Helm-Diff plugin install result: $diff_plugin_result"
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}

setupHelmDeps $untar
