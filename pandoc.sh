#!/usr/bin/env bash

PWD=.
SOURCEDIR="${PWD}/content/docs/isms"
BUILD_DIR="${PWD}/public/pdf"
REDACT=0
DRAFT=0
CURRENT_YEAR=`date +"%Y"`
export PATH=$PATH:"${PWD}/node_modules/.bin/" # Add node_modules/.bin to the path for mermaid-filter
ERROR_COLOR='\033[0;31m'
NO_COLOR='\033[0m'


# if ctrl-c is pressed,  break the loop and cleanup
trap ctrl_c INT
function ctrl_c() {
  echo "Cleaning up..."
  rm -rf "${BUILD_DIR}/tmp.*"
  rm -rf "${BUILD_DIR}/*.log"
  exit 1
}

## The below are low priority as the source of truth is still the markdown files
# TODO: Fix risk-assessment.md's tables or any md that uses hugo shortcodes
# TODO: Handle callouts
# TODO: Links to PDFs in the docs/single.html template

build_documents(){

  # array of files
  FILES=$(find "${SOURCEDIR}" -type f -name "*.md" -not -name "_index.md")
  TOTAL_FILES=$(echo "$FILES" | tr ' ' '\n' | wc -l)

  echo "Building PDFs from ${TOTAL_FILES} markdown files in ${SOURCEDIR}..."
  
  # create output_FILE directory
  mkdir -p "${BUILD_DIR}"

  global_arguments=(
    # Pandoc variables for all files
    -V papersize=letter # Set paper size to letter
    -V titlepage=true # Enable title page
    -V titlepage-rule-color=ff5c39  # Set title page rule color to SC2 orange
    -V titlepage-logo=static/SC2.png # Set title page logo
    -V toc-own-page=true  # Enable table of contents on its own page
    -V toc=true # Enable table of contents
    -V institution="SC2" # Set institution
    -V toc-depth=3  # Set table of contents depth
    -V logo-width=6cm # Set logo width
    -V header-right='\includegraphics[width=4cm]{static/logo.png}' # Set the right header to the logo
    -V table-use-row-colors=true  # Enable row colors in tables
    -V footer-left="SC2 \textcopyright ${CURRENT_YEAR}"  # Set the left footer to SC2
    -V footer-center="Confidental"  # Set the center footer to Confidential

    # Pandoc options
    --template eisvogel --listings  # Use eisvogel template
    --webtex # Enable webtex for math rendering
    --pdf-engine=xelatex # Use xelatex engine
    --data-dir=themes/pdf/  # Set data directory to use the custom template
    --resource-path=./ # Set resource path
    -F mermaid-filter  # Use mermaid filter https://github.com/raghur/mermaid-filter
  )

  if [ $DRAFT -eq 1 ]; then
    global_arguments+=(
      -V page-background=themes/pdf/static/draft.png  # Set the page background to the draft watermark
      -V page-background-opacity=0.8  # Set the page background opacity
    )
  fi

  FILE_COUNT=0

  # loop through files
  for FILE in ${FILES[@]}; do
    
    FILE_COUNT=$((FILE_COUNT+1))
    
    LAST_REVIEW_DATE=$(yq --front-matter=extract '.last_review_date' "${FILE}")
    VERSION=$(yq --front-matter=extract '.version' "${FILE}")
    TITLE=$(yq --front-matter=extract '.title' "${FILE}")
    DATE=`date -d"${LAST_REVIEW_DATE}" +"%B %d, %Y"`
    if [ $REDACT -eq 1 ]; then
      TITLE="${TITLE} (Redacted)"
    fi
    if [ $DRAFT -eq 1 ]; then
      TITLE="${TITLE} (Draft)"
    fi

    OUTPUT_FILE=$(echo "${BUILD_DIR}/${TITLE} - v${VERSION}.pdf" | tr ' ' '_')

    echo "Processing ${FILE_COUNT}/${TOTAL_FILES}: ${FILE} --> ${OUTPUT_FILE}"

    TMP_FILE=$(mktemp --tmpdir="${BUILD_DIR}" --suffix=.md)

    # default action is to copy the file
    cp "${FILE}" "${TMP_FILE}"

    # redact shortcode
    if [ $REDACT -eq 1 ]; then
      # redact the file using awk. See comments in redact.awk for more information
      awk -f ./scripts/helpers/redact.awk "${FILE}" > "${TMP_FILE}"

      if [ $? -ne 0 ]; then
        echo "${ERROR_COLOR}Error: Failed to redact file${NO_COLOR}"
        exit 1
      fi
    fi

    # Replace kroki code fence with mermaid-filter's
    sed 's/```kroki.*/```{.mermaid format=svg}/g' -i "${TMP_FILE}"

    FILEDIR=$(dirname "${FILE}")

    local_args=(
      "${TMP_FILE}" -o "${OUTPUT_FILE}"   # Input and output_FILE files
      -V subtitle="Version ${VERSION}"  # Use the subtitle field for the version
      -V date="Last Reviewed ${DATE}" # Set the date with the last review date
      --resource-path="${FILEDIR}" # Set resource path for current file's directory
    );

    # merge global and local arguments for pandoc
    args=("${global_arguments[@]}" "${local_args[@]}")

    # Build the PDF
    pandoc "${args[@]}"


    if [ $? -ne 0 ]; then
      echo "${ERROR_COLOR}Error: Failed to build PDF for ${FILE}${NO_COLOR}"
    fi

    # Cleanup
    rm "${TMP_FILE}"
  done
}


Help()
{
  # Display Help
  echo "Builds documentation from markdown files using pandoc."
  echo
  echo "Syntax: $0 [-h|r|d] [-s <source directory>]"
  echo "options:"
  echo "r     Enable redactions"
  echo "d     Enable draft watermark"
  echo "s     Set source directory"
  echo "h     Print this Help."
  echo
}
while getopts ":hrcds:" option; do
  case $option in
    h) # display Help
    Help
    exit;;
    r) # Build with redactions enabled
      REDACT=1
      echo "Redactions enabled"
    ;;
    d) # Build with draft watermark enabled
      DRAFT=1
      echo "Draft watermark enabled"
    ;;
    s) # Set source directory
      SOURCEDIR=$OPTARG
      echo "Setting source directory to $SOURCEDIR"
    ;;
  \?) # Invalid option
    echo "Error: Invalid option: $OPTARG"
    Help
    exit;;
  esac
done
build_documents
