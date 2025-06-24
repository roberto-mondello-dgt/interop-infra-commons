function setupHelmDeps() 
{
    local untar=$1

    cd "$ROOT_DIR"

    # Pulizia iniziale e creazione della struttura
    rm -rf charts
    mkdir -p charts/charts

    # Copia temporanea di Chart.yaml dentro charts/
    cp Chart.yaml charts/

    echo "# Helm dependencies setup #"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null
    helm repo update > /dev/null

    # Vai nella directory temporanea
    cd charts

    helm dep build > /dev/null

    if [[ $untar == true ]]; then
        cd charts  # charts/charts
        for filename in *.tgz; do 
            dirname=$(basename "$filename" .tgz)
            rm -rf "../$dirname"
            mkdir -p "../$dirname"
            tar -xzf "$filename" -C "../$dirname" --strip-components=1
        done
        cd ..
    fi

    # Pulizia finale dei file temporanei
    rm -rf Chart.yaml charts/*.tgz charts/charts

    # Debug finale (opzionale)
    echo "-- Final charts structure: --"
    ls -la "$ROOT_DIR/charts"

    # Helm diff plugin
    set +e
    if ! helm plugin list | grep -q "diff"; then
        helm plugin install https://github.com/databus23/helm-diff
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}
