#!/bin/sh
# This script downloads all files from a Google drive into a local directory.
# It relies on https://github.com/glotlabs/gdrive, which expects to find
# google drive credentials on /root/.config/gdrive3.
#
# Limitations: does not export Google Docs.
#
# Environment variables:
# LOCAL_FOLDER_PATH: the directory where the files will be downloaded. Must exist.
# ACCOUNT: the email address of the accoumt to use.
[[ -d "$LOCAL_FOLDER_PATH" ]] || mkdir -p "$LOCAL_FOLDER_PATH"
[[ -z "$ACCOUNT" ]] && echo "ACCOUNT must be set to an email address" >&2 && exit 1

echo "Copying all Google drive files to $LOCAL_FOLDER_PATH"

cd "$LOCAL_FOLDER_PATH"
gdrive account switch "$ACCOUNT"

for folder in $(gdrive files list | grep folder | cut -d' ' -f1)
do
  echo "Downloading folder with id $folder"
  gdrive files download --recursive "$folder"
done

for document in $(gdrive files list | grep regular | cut -d' ' -f1)
do
  echo "Downloading file with id $document"
  gdrive files download "$document"
done
