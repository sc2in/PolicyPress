#!/bin/bash

# Set up internal state
OUTPUT_DIR='internal'
INPUT_FILE='pdfConversion.txt'
HUGO_PID=-1
STARTED_HUGO=0
if [[ $REDACT != "" ]]; then
  echo "Creating redacted versions"
  OUTPUT_DIR='public'
fi


# Start the hugo server in the background using the pdf theme and allow it to settle
start_hugo (){
  HUGO_PID=`pgrep hugo`
  ./copy_node_modules.sh
  if [[ $HUGO_PID == "" ]]; then
    echo 'Starting Hugo server'
    npm run server:pdf &
    echo "Sleeping 5 seconds to allow Hugo to settle"
    sleep 5
    HUGO_PID=`pgrep hugo`
    STARTED_HUGO=1
    echo "Hugo running with PID ${HUGO_PID}"
  fi
}


# Stop the hugo server
stop_hugo(){
  if [[ $STARTED_HUGO -eq 1 ]]; then
    echo  'Stopping Hugo server'
    kill $HUGO_PID
  fi
  if [[ $DOCKER_RUNNING == "true" ]]; then
    echo "Running in docker. Linking cached node_modules"
    rm node_modules
  fi
}

# Build the PDFs
build_pdfs(){

  mkdir -p ${OUTPUT_DIR}/pdf
  # Get the list of files to convert
  grep -v -e "^#" -e "^[[:space:]]*$" "${INPUT_FILE}" | \
  while read relURL;
  do
    # clean the input
    relURL=`echo ${relURL} | tr -d '\r'`
    echo "Converting ${relURL}"

    # Parse the metadata from the page using hugo
    echo "getting metadata"
    URL="http://localhost:1313/${relURL}"
    CONTENT=`curl -s "${URL}"`
    TITLE=`echo ${CONTENT} |  tr "\n" " " | sed 's|.*<title>\([^<]*\).*</head>.*|\1|;s|^\s*||;s|\s*$||'`
    VERSION=`echo ${CONTENT} | awk '/version/{ gsub(/.*version=\042|\042.*/,"");print }' `
    LASTREVIEW=`echo ${CONTENT} | awk '/last_review_date/{ gsub(/.*last_review_date=\042|\042.*/,"");print }'`
    LASTDATE=`date -d"${LASTREVIEW}" +"%B %d, %Y"`

    # Create the cover page using the metadata + template
    echo "making cover for ${TITLE} v${VERSION} last review ${LASTREVIEW}"
    sed -e "s/%TITLE%/${TITLE}/g" -e "s/%VERSION%/${VERSION}/g" -e "s/%DATE%/${LASTDATE}/g" "themes/pdf/layouts/docs/cover.html" > cover.tmp.html
    if [[ ${PUBLISH} != "true" ]]
    then
      echo "Adding draft watermark"
      sed -i -e "s/%DRAFT%/body{background: url('themes\/pdf\/static\/draft.png');background-repeat: repeat-y;background-position: center;background-attachment: fixed;background-size: 100%;}/g" cover.tmp.html
    else
      echo "Removing draft watermark"
      sed -i -e "s/%DRAFT%//" cover.tmp.html
    fi

    # Convert the page to PDF using wkhtmltopdf
    OUTPUT="./${OUTPUT_DIR}/pdf/${TITLE}-v${VERSION}.pdf"
    echo "Converting ${i} - ${VERSION}"
    wkhtmltopdf \
    --outline-depth 2 \
    --enable-internal-links \
    --header-html themes/pdf/layouts/docs/header.html \
    --footer-html themes/pdf/layouts/docs/footer.html \
    -B 20 -T 20 -L 20 -R 20 \
    --enable-local-file-access \
    cover cover.tmp.html \
    "${URL}?version=${VERSION}" \
    "${OUTPUT}"

    # Set the last review date on the PDF for file distribution
    touch -d"${LASTREVIEW}" "${OUTPUT}"

    # Clean up
    rm cover.tmp.html 2> /dev/null
  done
}

start_hugo
build_pdfs
stop_hugo
