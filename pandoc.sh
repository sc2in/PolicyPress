#!/usr/bin/env bash

WORKDIR=$DEVBOX_PROJECT_ROOT
CONFIG="${WORKDIR}/config.toml"
REDACT=0
DRAFT=0
BUILD_DIR="${WORKDIR}/public/pdf"

POLICY_ROOT=$(tomlq -r '.extra.policy_root' "${CONFIG}" )
LOGO_PATH=static/$(tomlq -r '.extra.logo' "${CONFIG}" )
ORG=$(tomlq -r '.extra.organization' "${CONFIG}" )
POLICY_ROOT=$(tomlq -r '.extra.policy_root' "${CONFIG}" )
POLICY_ROOT=$(tomlq -r '.extra.policy_root' "${CONFIG}" )
POLICY_DIR=$(dirname content/${POLICY_ROOT})
CURRENT_YEAR=`date +"%Y"`


ERROR_COLOR='\033[0;31m'
NO_COLOR='\033[0m'


FILES=$(find "${POLICY_DIR}" -type f -name "*.md" -not -name "_index.md")
TOTAL_FILES=$(echo "$FILES" | tr ' ' '\n' | wc -l)

echo "Building PDFs from ${TOTAL_FILES} markdown files in ${POLICY_DIR}..."
mkdir -p "${BUILD_DIR}"

COLOR=$(magick ${LOGO_PATH} -scale 1x1\! -format '%[pixel:u]\n' info: | grep -Po "#[[:xdigit:]]{6}")
global_arguments=(
  # Pandoc variables for all files
  -V papersize=letter # Set paper size to letter
  -V titlepage=true # Enable title page
  -V titlepage-rule-color=${COLOR}  # Set title page rule color to SC2 orange
  -V titlepage-logo=${LOGO_PATH} # Set title page logo
  -V toc-own-page=true  # Enable table of contents on its own page
  -V toc=true # Enable table of contents
  -V institution="${ORG}" # Set institution
  -V toc-depth=3  # Set table of contents depth
  -V logo-width=6cm # Set logo width
  -V header-right="\includegraphics[width=2cm,height=2cm]{${LOGO_PATH}}" # Set the right header to the logo
  -V table-use-row-colors=true  # Enable row colors in tables
  -V footer-left="${ORG} \textcopyright ${CURRENT_YEAR}"  # Set the left footer to SC2
  -V footer-center="Confidental"  # Set the center footer to Confidential

  # Pandoc options
  --template eisvogel # Use eisvogel template
  --listings  
  --webtex # Enable webtex for math rendering
  --pdf-engine=xelatex # Use xelatex engine
  --data-dir=$DEVBOX_PROJECT_ROOT  # Set data directory to use the custom template
  --resource-path=$DEVBOX_PROJECT_ROOT # Set resource path
  -F mermaid-filter  # Use mermaid filter https://github.com/raghur/mermaid-filter
)

if [ $DRAFT -eq 1 ]; then
  global_arguments+=(
    -V page-background=static/draft.png  # Set the page background to the draft watermark
    -V page-background-opacity=0.8  # Set the page background opacity
  )
fi

FILE_COUNT=0

rm -rf "${BUILD_DIR}/*"

# loop through files
for FILE in ${FILES[@]}; do
  
  FILE_COUNT=$((FILE_COUNT+1))

  echo "Processing file ${FILE_COUNT}/${TOTAL_FILES}: ${FILE}"

  tmpfile=$(mktemp --suffix .md)
  trap 'rm -f "$tmpfile"' EXIT

  # Shortcode emulation
  # mermaid shortcode emulation
  awk '
      /{%\s*mermaid\(\)\s*%}/ { print "~~~mermaid"; in_mermaid=1; next }
      in_mermaid && /{%\s*end\s*%}/ { print "~~~"; in_mermaid=0; next }
      { print }
  ' "${FILE}" > "$tmpfile"
  # Replace org() shortcode with the organization name
  sed -i 's/{{ org() }}/'"${ORG}"'/g' "$tmpfile"

  VERSION=$(yq --front-matter extract -r '.extra.major_revisions | sort_by("date")| .[0].version' "${tmpfile}")

  TITLE=$(yq --front-matter extract -r  '.title' "${tmpfile}" )
  echo "Title: ${TITLE}, Date: ${LAST_REVIEW_DATE}, Version: ${VERSION}"
  if [ $REDACT -eq 1 ]; then
    TITLE="${TITLE} (Redacted)"
  fi
  if [ $DRAFT -eq 1 ]; then
    TITLE="${TITLE} (Draft)"
  fi

  OUTPUT_FILE=$(echo "${BUILD_DIR}/${TITLE} - v${VERSION}.pdf" | tr ' ' '_')

  FILEDIR=$(dirname "${FILE}")

  local_args=(
    "${tmpfile}" -o "${OUTPUT_FILE}"   # Input and output_FILE files
    --resource-path="${FILEDIR}" # Set resource path for current file's directory
  );

    # merge global and local arguments for pandoc
  args=("${global_arguments[@]}" "${local_args[@]}")

  # Build the PDF
  pandoc "${args[@]}"

  if [ $? -ne 0 ]; then
    echo "${ERROR_COLOR}Error: Failed to build PDF for ${FILE}${NO_COLOR}"
  fi


done