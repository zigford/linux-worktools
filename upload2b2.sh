#!/bin/bash

set -euo pipefail

bucket="BlogVideos"
inputFile="${1}"
destFile="${2:-$inputFile}"

echo "Upload $inputFile to B2 as $destFile"
sha=$(shasum "${inputFile}" | awk '{print $1}')
b2cli upload-file --sha1 "${sha}" --threads 8 \
    "${bucket}" \
    "${inputFile}" \
    "${destFile}"
