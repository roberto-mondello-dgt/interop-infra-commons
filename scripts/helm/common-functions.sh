#!/bin/bash
set -euo pipefail

SCRIPTS_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#ROOT_DIR=$PROJECT_DIR

function isCronjobEnvConfigValid()
{
    CRONJOB=$1
    ENVIRONMENT=$2
    CRONJOBS_DIR=$(getCronjobsDir)

    if [[ ! -d "$CRONJOBS_DIR/$CRONJOB/$ENVIRONMENT" ]]; then
        echo ""
    else
        echo "true"
    fi
}

function isMicroserviceEnvConfigValid()
{
    MICROSERVICE=$1
    ENVIRONMENT=$2
    MICROSERVICE_DIR=$(getMicroservicesDir)

    if [[ ! -d "$MICROSERVICE_DIR/$MICROSERVICE/$ENVIRONMENT" ]]; then
        echo ""
    else
        echo "true"
    fi
}

function getCronjobsDir()
{
    echo "$ROOT_DIR/jobs"
}

function getMicroservicesDir()
{
    echo "$ROOT_DIR/microservices"
}

function getAllowedMicroservices()
{
    local DELIMITER=";"
    local SERVICES_DIR=$(getMicroservicesDir)
    local ALLOWED_SERVICES=""

    for dir in "$SERVICES_DIR"/*;
    do
        CURRENT_SVC=$(basename "$dir");
        if [[ $ALLOWED_SERVICES == "" ]]; then
            ALLOWED_SERVICES=$CURRENT_SVC
        else
            ALLOWED_SERVICES=$ALLOWED_SERVICES$DELIMITER$CURRENT_SVC
        fi
    done

    echo $ALLOWED_SERVICES
}


function getAllowedCronjobs()
{
    local DELIMITER=";"
    local CRONJOBS_DIR=$(getCronjobsDir)
    local ALLOWED_CRONJOBS=""

    for dir in "$CRONJOBS_DIR"/*;
    do
        CURRENT_JOB=$(basename "$dir");
        if [[ $ALLOWED_CRONJOBS == "" ]]; then
            ALLOWED_CRONJOBS=$CURRENT_JOB
        else
            ALLOWED_CRONJOBS=$ALLOWED_CRONJOBS$DELIMITER$CURRENT_JOB
        fi
    done

    echo $ALLOWED_CRONJOBS
}

function isAllowedValue()
{
    local LIST=$1
    local DELIMITER=$2
    local VALUE=$3
    local RESULT=$(echo $LIST | tr "$DELIMITER" '\n' | grep -i $VALUE)
    echo $RESULT
}

function isAllowedMicroservice()
{
    local ALLOWED_SERVICES=$(getAllowedMicroservices)
    local DELIMITER=";"
    local SERVICE=$1
    local RESULT=$(isAllowedValue $ALLOWED_SERVICES $DELIMITER $SERVICE)

    if [[ -z $RESULT || $RESULT == "" ]]; then
        echo ""
    else
        echo "true"
    fi
}

function isAllowedCronjob()
{
    local ALLOWED_CRONJOBS=$(getAllowedCronjobs)
    local DELIMITER=";"
    local CRONJOB=$1
    local RESULT=$(isAllowedValue $ALLOWED_CRONJOBS $DELIMITER $CRONJOB)

    if [[ -z $RESULT || $RESULT == "" ]]; then
        echo ""
    else
        echo "true"
    fi
}
function getAllowedMicroservices()
{
    local DELIMITER=";"
    local SERVICES_DIR=$(getMicroservicesDir)
    local ALLOWED_SERVICES=""

    for dir in "$SERVICES_DIR"/*;
    do
        CURRENT_SVC=$(basename "$dir");
        if [[ $ALLOWED_SERVICES == "" ]]; then
            ALLOWED_SERVICES=$CURRENT_SVC
        else
            ALLOWED_SERVICES=$ALLOWED_SERVICES$DELIMITER$CURRENT_SVC
        fi
    done

    echo $ALLOWED_SERVICES
}
function getAllowedMicroservicesForEnvironment()
{
    local DELIMITER=";"
    local ENVIRONMENT=$1
    if [[ -z $ENVIRONMENT || $ENVIRONMENT == "" ]]; then
        exit 1
    fi

    local MICROSERVICES_DIR=$(getMicroservicesDir)
    if [[ ! -d "$MICROSERVICES_DIR" ]]; then
        exit 1
    fi

    local ALLOWED_SERVICES=""

    for dir in "$MICROSERVICES_DIR"/*;
    do
        CURRENT_SVC=$(basename "$dir");

        if [[ -d "$dir/$ENVIRONMENT" ]]; then
            if [[ $ALLOWED_SERVICES == "" ]]; then
                ALLOWED_SERVICES=$CURRENT_SVC
            else
                ALLOWED_SERVICES=$ALLOWED_SERVICES$DELIMITER$CURRENT_SVC
            fi
        fi
    done

    echo $ALLOWED_SERVICES
}

function getAllowedCronjobsForEnvironment()
{
    local DELIMITER=";"
    local ENVIRONMENT=$1
    if [[ -z $ENVIRONMENT || $ENVIRONMENT == "" ]]; then
        exit 1
    fi

    local CRONJOBS_DIR=$(getCronjobsDir)
    if [[ ! -d "$CRONJOBS_DIR" ]]; then
        exit 1
    fi

    local ALLOWED_CRONJOBS=""

    for dir in "$CRONJOBS_DIR"/*;
    do
        CURRENT_JOB=$(basename "$dir");
        if [[ -d "$dir/$ENVIRONMENT" ]]; then
            if [[ $ALLOWED_CRONJOBS == "" ]]; then
                ALLOWED_CRONJOBS=$CURRENT_JOB
            else
                ALLOWED_CRONJOBS=$ALLOWED_CRONJOBS$DELIMITER$CURRENT_JOB
            fi
        fi
    done

    echo $ALLOWED_CRONJOBS
}