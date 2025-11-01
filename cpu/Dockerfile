# CPU stress container — Alpine build
FROM alpine:3.20

# We need bash, coreutils (nproc), dumb-init & stress-ng
RUN apk add --no-cache bash coreutils dumb-init stress-ng 

# ---- consistent IDs across all stress containers ----
ARG USERNAME=cpu
ARG GROUPNAME=stresscontainers
ARG UID=10001
ARG GID=20001   # <-- set this to the your host's stresscontainers GID

# Create group + user with fixed numeric IDs
RUN addgroup -S -g ${GID} ${GROUPNAME} \
 && adduser  -S -u ${UID} -G ${GROUPNAME} -h /home/${USERNAME} -s /sbin/nologin ${USERNAME} \
 && mkdir -p /home/${USERNAME}

# Create workdir and hand it to cpu
WORKDIR /worker

# Copy code (own at copy-time for fewer layers)
COPY --chown=${UID}:${GID} cpu_stress.sh /worker/cpu_stress.sh
RUN chmod +x /worker/cpu_stress.sh

# Use this user
USER cpu

# Use dumb-init so SIGTERM/SIGINT cleanly stop stress-ng
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/worker/cpu_stress.sh"]

# OCI metadata
LABEL org.opencontainers.image.title="Module - CPU stress (stress-ng)" \
      org.opencontainers.image.description="Single-command CPU stress container with customizable parameters" \
      org.opencontainers.image.licenses="MIT"
