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

# Funzione per mostrare le dipendenze leggendo direttamente Chart.yaml
# Evita la scansione ricorsiva di helm dep list
function showDependenciesFromChart() {
    if [[ -f "Chart.yaml" ]]; then
        echo "-- Dependencies from Chart.yaml --"
        if grep -q "dependencies:" Chart.yaml; then
            # Header formattato come helm dep list
            printf "%-35s %-15s %-30s\n" "NAME" "VERSION" "REPOSITORY"
            printf "%-35s %-15s %-30s\n" "----" "-------" "----------"
            
            # Estrae e formatta le dipendenze dal Chart.yaml
            awk '
            /^dependencies:/ { in_deps = 1; next }
            in_deps && /^[[:space:]]*-/ { 
                if ($0 ~ /name:/) { 
                    gsub(/.*name:[[:space:]]*/, ""); 
                    name = $0; 
                    gsub(/["\047]/, "", name);
                }
                if ($0 ~ /version:/) { 
                    gsub(/.*version:[[:space:]]*/, ""); 
                    version = $0; 
                    gsub(/["\047]/, "", version);
                }
                if ($0 ~ /repository:/) { 
                    gsub(/.*repository:[[:space:]]*/, ""); 
                    repo = $0; 
                    gsub(/["\047]/, "", repo);
                    printf "%-35s %-15s %-30s\n", name, version, repo;
                    name = ""; version = ""; repo = "";
                }
            }
            in_deps && /^[[:space:]]*$/ { in_deps = 0 }
            !in_deps && !/^[[:space:]]*$/ && !/^dependencies:/ { in_deps = 0 }
            ' Chart.yaml
        else
            echo "No dependencies found in Chart.yaml"
        fi
    else
        echo "No Chart.yaml found"
    fi
}

function setupHelmDeps() 
{
    untar=$1

    cd $ROOT_DIR
    
    # Trova la directory del chart
    CHART_DIR=""
    if [[ -f "Chart.yaml" ]]; then
        CHART_DIR="."
    elif [[ -f "helm/Chart.yaml" ]]; then
        CHART_DIR="helm"
    elif [[ -f "chart/Chart.yaml" ]]; then
        CHART_DIR="chart"
    elif [[ -f "charts/Chart.yaml" ]]; then
        CHART_DIR="charts"
    else
        echo "Error: No Chart.yaml found in expected locations (., helm/, chart/, charts/)"
        exit 1
    fi

    echo "# Helm dependencies setup #"
    echo "Working with chart in: $CHART_DIR"
    
    # Vai nella directory del chart
    cd "$CHART_DIR"
    
    # Rimuovi charts esistenti per evitare conflitti
    rm -rf charts
    
    echo "-- Add PagoPA eks repos --"
    helm repo add interop-eks-microservice-chart https://pagopa.github.io/interop-eks-microservice-chart > /dev/null
    helm repo add interop-eks-cronjob-chart https://pagopa.github.io/interop-eks-cronjob-chart > /dev/null

    echo "-- Update PagoPA eks repo --"
    helm repo update interop-eks-microservice-chart > /dev/null
    helm repo update interop-eks-cronjob-chart > /dev/null

    if [[ $verbose == true ]]; then
        echo "-- Search PagoPA charts in repo --"
        helm search repo interop-eks-microservice-chart > /dev/null
        helm search repo interop-eks-cronjob-chart > /dev/null
    fi

    # Mostra le dipendenze PRIMA di helm dep up per evitare scansione ricorsiva
    if [[ $verbose == true ]]; then
        showDependenciesFromChart
    fi
    
    echo "-- Build chart dependencies --"
    dep_up_result=$(helm dep up --destination ./charts)
    if [[ $verbose == true ]]; then
        echo "$dep_up_result"
    fi

    # Ora che abbiamo la directory charts, possiamo usare helm dep list in sicurezza
    if [[ $verbose == true && -d "charts" ]]; then
        echo "-- Chart dependencies status (after build) --"
        helm dep list | awk '{printf "%-35s %-15s %-20s\n", $1, $2, $3}' 2>/dev/null || echo "No dependencies to list"
    fi

    # Estrai i file .tgz se richiesto
    if [[ $untar == true && -d "charts" ]]; then
        echo "-- Extracting chart dependencies --"
        cd charts
        for filename in *.tgz; do 
            if [[ -f "$filename" ]]; then
                # Verifica che sia un chart Helm valido prima di estrarlo
                if tar -tzf "$filename" | grep -q -E "(Chart.yaml|chart.yaml)" 2>/dev/null; then
                    if [[ $verbose == true ]]; then
                        echo "Extracting chart: $filename"
                    fi
                    tar -xf "$filename" && rm -f "$filename"
                else
                    if [[ $verbose == true ]]; then
                        echo "Skipping non-chart file: $filename"
                    fi
                    # Rimuovi file che non sono chart validi
                    rm -f "$filename"
                fi
            fi
        done
        cd ..
    fi

    # Torna alla directory root
    cd "$ROOT_DIR"

    set +e
    # Install helm diff plugin (ignora errori se già installato)
    helm plugin install https://github.com/databus23/helm-diff 2>/dev/null
    diff_plugin_result=$?
    if [[ $verbose == true ]]; then
        echo "Helm-Diff plugin install result: $diff_plugin_result"
    fi
    set -e

    echo "-- Helm dependencies setup ended --"
    exit 0
}

# Avvia la funzione principale
setupHelmDeps $untar