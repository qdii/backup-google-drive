#!/bin/sh
echo "Backup Google Drive, running as $(id)"
download-gdrive.sh; backup.sh
