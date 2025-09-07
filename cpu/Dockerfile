# CPU stress container — Alpine build
FROM alpine:3.20

# We need bash, coreutils (nproc), dumb-init & stress-ng
RUN apk add --no-cache bash coreutils dumb-init stress-ng 

# Create non-root user (uid 10001)
RUN addgroup -S cpu \
 && adduser -S -u 10001 -G cpu -h /home/cpu -s /sbin/nologin cpu

WORKDIR /
COPY stress.sh /usr/local/bin/stress.sh
RUN chmod +x /usr/local/bin/stress.sh
USER cpu

# Use dumb-init so SIGTERM/SIGINT cleanly stop stress-ng
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/stress.sh"]

# OCI metadata
LABEL org.opencontainers.image.title="Module - CPU stress (stress-ng)" \
      org.opencontainers.image.description="Single-command CPU stress container with customizable parameters" \
      org.opencontainers.image.licenses="MIT"
