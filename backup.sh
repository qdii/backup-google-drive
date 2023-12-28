#!/bin/sh
#
# This script backs a directory up, and uploads the backup to a SSH server.
#
# On the server, a directory containing the date of the backup is created,
# for instance 20230402 if the script was launched on the 2nd of April 2023.
# The files are copied inside this directory.
#
# If a former directory exists, the files that are unchanged are linked to
# it. So for instance, if 20230101/big_file exists and 20230102/big_file is
# unchanged, then 20230102 will be a hard (not symbolic) link. This is achieved
# using --link-dest from rsync (see man rsync).
#
# The following environment variables must be defined:
# - LOCAL_FOLDER_PATH: a relative or absolute path to the directory to backup.
#     The script will exit with value 10 if the path does not exist, or
#     if the file is not a directory.
# - REMOTE_FOLDER_PATH: a relative or absolute path to the directory in which
#     the backups are created.
# - REMOTE_USER: The username to use when connecting to the SSH server.
# - REMOTE_SERVER: The server to connect to.

# This functions returns the last folder of the form 20230402 on the remote
# SSH server, or an empty string if none is found.
find_newest_folder() {
  ssh -o StrictHostKeyChecking=no -l "${REMOTE_USER}" "${REMOTE_SERVER}" "cd ${REMOTE_FOLDER_PATH} && ls -td ./*/ | head -1"
}

[[ -d "${LOCAL_FOLDER_PATH}" ]] || exit 10

echo "Listing file in local folder"
ls -l ${LOCAL_FOLDER_PATH}

# E.g. 20230402.
remote_folder=${REMOTE_FOLDER_PATH}/$(date +'%Y%m%d')

echo "Looking for previous folder..."
last_folder=$(find_newest_folder)
if [[ -n "$last_folder" ]]; then
  echo "Found previous folder: ${REMOTE_FOLDER_PATH}/${last_folder}"
  link_parameter="--link-dest=${REMOTE_FOLDER_PATH}/${last_folder}"
else
  echo "No previous folder found."
  link_parameter="--progress"
fi

echo "Creating remote folder: ${remote_folder}"
ssh -o StrictHostKeyChecking=no -l "${REMOTE_USER}" "${REMOTE_SERVER}" "mkdir -p ${remote_folder}"

cd ${LOCAL_FOLDER_PATH}
echo "Copying files."
rsync -e "ssh -o StrictHostKeyChecking=no" --verbose --archive "${link_parameter}" * "${REMOTE_USER}"@"${REMOTE_SERVER}":"${remote_folder}"
echo "Done copying files."
