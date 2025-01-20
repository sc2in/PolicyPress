#!/usr/bin/env bash

# This script is used to check if the markdown files in the isms directory
# have a last review date that is within the last 12 months of the current date
# or a given date

ISMS_DOC_DIR="./content/docs/isms"

ERROR_COLOR='\033[0;31m'
NO_COLOR='\033[0m'
SUCCESS_COLOR='\033[0;32m'
WARNING_COLOR='\033[0;33m'

# For each markdown file in the isms directory, check if the last review date is
# within the last 12 months of the current date


# Get the current date
if [[ -z $1 ]]; then
    current_date=$(gdate +%Y-%m-%d)
else
    current_date=$1
    echo -e "${WARNING_COLOR}Warning: Using the provided date ${current_date}${NO_COLOR}"
fi

# Get the date 12 months before the current_date
back_date=$(gdate -d "${current_date} -12 months" +%Y-%m-%d)
echo -e "${WARNING_COLOR}Warning: Using the back date of ${current_date}${NO_COLOR}"

total_count=0
success_count=0
error_count=0

for file in $(find ${ISMS_DOC_DIR} -name '*.md' -not -name '_index.md'); do
    
    # Get the last review date
    last_review_date=$(yq --front-matter="extract" '.last_review_date' "${file}")
    total_count=$((total_count+1))

    # If the last review date is not present, warn the user
    if [[ -z $last_review_date ]]; then
        echo -e "${ERROR_COLOR}Error: ${file} does not contain a last review date${NO_COLOR}"
        error_count=$((error_count+1))
        continue
    fi

    # If the last review date is not within the last 12 months, warn the user
    if [[ $last_review_date < $back_date ]]; then
        echo -e "${ERROR_COLOR}Error: ${file} has a last review date of ${last_review_date} which is not within the last 12 months${NO_COLOR}"
        error_count=$((error_count+1))
    else
        # echo -e "${SUCCESS_COLOR}Success: ${file} has a last review date of ${last_review_date} which is within the last 12 months${NO_COLOR}"
        success_count=$((success_count+1))
    fi
done

# Report on the status of the last review date
echo 
echo -e "${WARNING_COLOR}${total_count} files were checked${NO_COLOR}"
echo -e "${SUCCESS_COLOR}${success_count} files have a last review date within the last 12 months of ${current_date}${NO_COLOR}"
if [[ $error_count -ne 0 ]]; then
    echo -e "${ERROR_COLOR}${error_count} files do not have a last review date or have a last review date that is not within the last 12 months of ${current_date}${NO_COLOR}"
    exit -1
fi