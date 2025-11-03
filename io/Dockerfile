# CPU stress container — Alpine build
FROM alpine:3.22

# We need bash, coreutils (nproc), dumb-init & fio
RUN apk add --no-cache bash coreutils dumb-init fio envsubst

# ---- consistent IDs across all stress containers ----
ARG USERNAME=io
ARG GROUPNAME=stresscontainers
ARG UID=10001
ARG GID=20001   # <-- set this to the your host's stresscontainers GID

# Create group + user with fixed numeric IDs
RUN addgroup -S -g ${GID} ${GROUPNAME} \
 && adduser  -S -u ${UID} -G ${GROUPNAME} -h /home/${USERNAME} -s /sbin/nologin ${USERNAME} \
 && mkdir -p /home/${USERNAME}

# Create workdir and hand it to io
WORKDIR /worker

# Copy code (own at copy-time for fewer layers)
COPY --chown=${UID}:${GID} io_stress.sh /worker/io_stress.sh
COPY --chown=${UID}:${GID} templates/ /worker/templates/
RUN chmod +x /worker/io_stress.sh && chown -R ${USERNAME}:${GROUPNAME} /worker

# Run as this user
USER io

# Use dumb-init so SIGTERM/SIGINT cleanly stop fio
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/worker/io_stress.sh"]

# OCI metadata
LABEL org.opencontainers.image.title="Module - IO stress (fio)" \
      org.opencontainers.image.description="Single-command IO stress container with customizable parameters" \
      org.opencontainers.image.licenses="MIT"
