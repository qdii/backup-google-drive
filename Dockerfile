FROM alpine:latest
RUN apk add --no-cache wget tar openssh rsync

# Download gdrive
RUN wget https://github.com/glotlabs/gdrive/releases/download/3.9.0/gdrive_linux-x64.tar.gz
RUN tar xzvf gdrive_linux-x64.tar.gz
RUN mv gdrive /usr/local/bin
RUN chmod a+rx /usr/local/bin/gdrive

# Prepare scripts
COPY ./backup-gdrive.sh /usr/local/bin
COPY ./download-gdrive.sh /usr/local/bin
COPY ./backup.sh /usr/local/bin
RUN chmod a+rx /usr/local/bin/backup-gdrive.sh /usr/local/bin/download-gdrive.sh /usr/local/bin/backup.sh

# gdrive looks for credentials in this folder. Allow user to mount it.
RUN mkdir /root/.config
VOLUME "/root/.config/gdrive3"

ENTRYPOINT ["sh", "/usr/local/bin/backup-gdrive.sh"]
