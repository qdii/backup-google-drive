# backup-google-drive

Backup a Google drive to a remote folder over SSH.

## Overview

Files are downloaded from Google Drive to a local folder using [glotlabs/gdrive](https://github.com/glotlabs/gdrive), then they are sent using rsync to a remote folder.

The tool does incremental backups: the files are created under a directory named after today's date (e.g. 20231228). If the exact same file is found under yesterday's date folder (that is 20231227), it is symlinked from there instead of copied. This means each iteration only appends new or modified files to the remote server.

## Limitations

There are some limitations to the tool:

1. Enough space needs to be allocated on the machine to store the entire Google Drive. We could improve that by interleaving downloads and uploads.

2. Only the 30 first items of the Google Drive Folders are uploaded. This is a configuration knob in gdrive that I still need to expose to the user.

3. Google docs/sheets are not downloaded. This is a limitation of Google Drive API: they need to be exported to another format (Word, Excel) first.

## Setup

[glotlabs/gdrive](https://github.com/glotlabs/gdrive) requires a client app to be created. See the [setup steps](https://github.com/glotlabs/gdrive/blob/main/docs/create_google_api_credentials.md#create-google-api-credentials-in-50-easy-steps) in that project.

If using the Dockerfile, the following environment variables must be set:

- `LOCAL_FOLDER_PATH`: A folder inside the container where the files will be downloaded before they are uploaded via rsync.

- `REMOTE_USER`: The user to upload the file as in the remote server.

- `REMOTE_SERVER`: The hostname or IP address of the remote server.

- `REMOTE_FOLDER_PATH`: The folder under which the files will be uploaded. Note that the files will be stored inside a subfolder called after today's date.

- `ACCOUNT`: The email address associated with the Google Drive (a.k.a. GAIA ID)

The following files must be mounted:

- `/root/.ssh/id_rsa`: The SSH private key to use when SSH-ing into the remote server

- `/root/.ssh/id_rsa.pub`: The SSH public key to use when SSH-ing into the remote server

- `/root/.config/gdrive3`: A folder that should contain `accounts.json`, `$ACCOUNT/secret.json` and `$ACCOUNT/tokens.json`. All 3 files are created by running `gdrive account add`.

### Kubernetes

Here's a sample configuration to backup Google Drive on a daily basis:

```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: gdrive-backup
spec:
  schedule: "@weekly"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: "Never"
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: arch
                    operator: In
                    values:
                    - x86
          initContainers:
          - name: prepare-gdrive-credentials
            image: busybox
            command: ['sh', '-c', 'cp -R /credentials/* /root/.config/gdrive3']
            volumeMounts:
            - name: credentials
              mountPath: "/credentials/myaccount@gmail.com"
              subPath: "myaccount@gmail.com"
            - name: accounts
              mountPath: "/credentials/accounts.json"
              subPath: "accounts.json"
            - name: gdrive-config
              mountPath: "/root/.config/gdrive3"
          containers:
          - name: gdrive-backup
            image: qdii/backup-gdrive:latest
            imagePullPolicy: "Always"
            env:
            - name: LOCAL_FOLDER_PATH
              value: "/tmp/app"
            - name: REMOTE_USER
              value: "qdii"
            - name: REMOTE_SERVER
              value: "backup.myserver.com"
            - name: REMOTE_FOLDER_PATH
              value: "/home/qdii/backups"
            - name: ACCOUNT
              value: "myaccount@gmail.com"
            volumeMounts:
            - name: ephemeral
              mountPath: "/tmp/app"
            - name: gdrive-config
              mountPath: "/root/.config/gdrive3"
            - name: backup
              mountPath: "/root/.ssh/id_rsa"
              subPath: ssh_private_key
            - name: backup
              mountPath: "/root/.ssh/id_rsa.pub"
              subPath: ssh_public_key
          volumes:
            - name: credentials
              projected:
                sources:
                  - secret:
                      name: gdrive
                      items:
                      - key: secret.json
                        path: "myaccount@gmail.com/secret.json"
                      - key: tokens.json
                        path: "myaccount@gmail.com/tokens.json"
            - name: accounts
              secret:
                secretName: gdrive
                items:
                - key: accounts.json
                  path: "accounts.json"
            - name: backup
              secret:
                secretName: backup
                defaultMode: 0400
            - name: ephemeral
              emptyDir:
                sizeLimit: 50Gi
            - name: gdrive-config
              emptyDir:
                sizeLimit: 10Mi
```

The `initContainer` is required because Kubernetes mounts secret and config-maps
read-only, but gdrive3 requires the folders to be writeable.
