#!/bin/bash
set -euo pipefail

function setupHelmDeps() 
{
    local untar=$1

    echo "[DEBUG] Starting setupHelmDeps"
    echo "[DEBUG] ROOT_DIR=$ROOT_DIR"

    cd "$ROOT_DIR"

    echo "[DEBUG] Cleaning and recreating 'charts' folder"
    rm -rf charts
    mkdir -p charts/charts

    echo "[DEBUG] Copying Chart.yaml temporarily"
    cp Chart.yaml charts/

    echo "# Helm dependencies setup #"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null
    helm repo update > /dev/null

    echo "[DEBUG] Running helm dep build inside charts"
    cd charts

    helm dep build

    echo "[DEBUG] Checking content after helm dep build"
    ls -la
    ls -la charts

    if [[ $untar == true ]]; then
        echo "[DEBUG] Untarring charts"
        cd charts
        for filename in *.tgz; do 
            dirname=$(basename "$filename" .tgz)
            rm -rf "../$dirname"
            mkdir -p "../$dirname"
            tar -xzf "$filename" -C "../$dirname" --strip-components=1
            echo "[DEBUG] Extracted $filename to ../$dirname"
        done
        cd ..
    fi

    echo "[DEBUG] Final charts structure after untar"
    ls -la "$ROOT_DIR/charts"

    echo "[DEBUG] Cleaning temporary files"
    rm -rf Chart.yaml charts/*.tgz charts/charts

    echo "[DEBUG] Final charts structure after cleanup"
    ls -la "$ROOT_DIR/charts"

    set +e
    if ! helm plugin list | grep -q "diff"; then
        helm plugin install https://github.com/databus23/helm-diff
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}

setupHelmDeps "$1"
