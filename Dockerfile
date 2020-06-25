FROM alpine/git:latest

# RUN apk add --no-cache bash rsync git
RUN apk add --no-cache bash rsync diffutils

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
