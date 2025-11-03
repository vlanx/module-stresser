# NET stress container — Alpine build
FROM alpine:3.22

# We need bash, dumb-init & iperf3
RUN apk add --no-cache bash dumb-init iperf3

# ---- consistent IDs across all stress containers ----
ARG USERNAME=network
ARG GROUPNAME=stresscontainers
ARG UID=10001
ARG GID=20001   # <-- set this to the your host's stresscontainers GID

# Create group + user with fixed numeric IDs
RUN addgroup -S -g ${GID} ${GROUPNAME} \
 && adduser  -S -u ${UID} -G ${GROUPNAME} -h /home/${USERNAME} -s /sbin/nologin ${USERNAME} \
 && mkdir -p /home/${USERNAME}

# Create workdir and hand it to network
WORKDIR /worker

# Copy code (own at copy-time for fewer layers)
COPY --chown=${UID}:${GID} network_stress.sh /worker/network_stress.sh
RUN chmod +x /worker/network_stress.sh && chown -R ${USERNAME}:${GROUPNAME} /worker

# Use this user
USER network

# Use dumb-init so SIGTERM/SIGINT cleanly stop iperf3
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/worker/network_stress.sh"]

# OCI metadata
LABEL org.opencontainers.image.title="Module - Network stress (iperf3)" \
      org.opencontainers.image.description="Single-command Network stress container with customizable parameters" \
      org.opencontainers.image.licenses="MIT"
