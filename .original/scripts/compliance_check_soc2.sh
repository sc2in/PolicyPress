#!/usr/bin/env bash

# This script is used to check if the markdown files in the isms directory

# The purpose of this script is to:
# 1. Open the TSC-2017 yaml file and read in the control IDs
# 2. For each markdown file in the isms directory, check if the control ID is 
# present under the "satifisfies.TSC" key
# 2.1 If the statifies.TSC key is not present, warn the user
# 3. If the control ID is present, make note of this
# 4. Report on the status of each control ID

ISMS_DOC_DIR="./content/docs/isms"
TSC_YAML="./data/opencontrols/standards/TSC-2017 (SOC2).yml"
TSC_KEY="TSC"

ERROR_COLOR='\033[0;31m'
NO_COLOR='\033[0m'
SUCCESS_COLOR='\033[0;32m'
WARNING_COLOR='\033[0;33m'

echo "Checking compliance with SOC2 TSC-2017 controls"

echo "Reading in control IDs from ${TSC_YAML}"
# Read in keys from the TSC-2017 yaml file as an array
keys=($(yq eval  'with_entries(select(.key != "name")) | keys | .[]'  "${TSC_YAML}" ))
# create an associative array to store the status of each control ID
declare -A control_status
for key in "${keys[@]}"; do
  control_status[${key}]="Not Satisfied"
done


echo "Checking if control IDs are present in the markdown files"

# For each markdown file in the isms directory, check if the control ID is
# present under the "satifisfies.TSC" key
for file in $(find ${ISMS_DOC_DIR} -name '*.md' -not -name '_index.md'); do
# Report on the status of each control ID
    
    # If the statifies.TSC key is not present, warn the user
    tsc_key_exists=$(yq --front-matter=extract "( . | has(\"satisfies\")) and ( .satisfies | has(\"${TSC_KEY}\"))" -r "${file}")
    if [[ $tsc_key_exists == "false" ]]; then
        echo "Warning: ${file} does not contain satisfies.TSC"
        continue
    fi

    # If the control ID is present, make note of this
    for control_id in "${keys[@]}"; do
        document_satisfies=($(yq --front-matter=extract '.satisfies.TSC | .[]' -r "${file}"))
        for satisfies in "${document_satisfies[@]}"; do

            if [[ $satisfies == $control_id ]]; then
                control_status[${control_id}]="Satisfied"
            fi
        
        done

    done

done

# Report on the status of each control ID
for control_id in "${keys[@]}"; do
    # echo "${control_id}: ${control_status[${control_id}]}"
    if [[ ${control_status[${control_id}]} == "Not Satisfied" ]]; then
        echo -e "${ERROR_COLOR}${control_id}: ${control_status[${control_id}]}${NO_COLOR}"
    else
        echo -e "${SUCCESS_COLOR}${control_id}: ${control_status[${control_id}]}${NO_COLOR}"
    fi
done
