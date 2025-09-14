# We need the latest build of `stress-ng` because the behavior we want
# from some flags is currently only available on its latest version. 
# Debian/Ubuntu/Alpine repositories at the moment only have v0.17 so 
# we need a build stage to build `stress-ng` from source.

# ---------- Builder: compile latest stress-ng on Alpine (musl) ----------
FROM alpine:3.22 AS build

RUN apk add --no-cache build-base git linux-headers
WORKDIR /src
RUN git clone https://github.com/ColinIanKing/stress-ng.git .

# Build
RUN make && strip stress-ng

# ---------- Running: create the final container with the previous `stress-ng` included ----------
# Memrate — (sequential & rate-limited)

FROM alpine:3.22

# Core tools + stress-ng + dumb-init + taskset
RUN apk add --no-cache \
      bash dumb-init

# bring in the freshly built stress-ng
COPY --from=build /src/stress-ng /usr/local/bin/stress-ng

# Non-root user
# Create non-root user (uid 10001)
RUN addgroup -S memory \
 && adduser -S -u 10001 -G memory -h /home/memory -s /sbin/nologin memory

# Create workdir and hand it to memory user
WORKDIR /worker
COPY memory_stress.sh /worker/memory_stress.sh
RUN chmod +x /worker/memory_stress.sh \
 && chown -R memory:memory /worker

# Use dumb-init so SIGTERM/SIGINT cleanly stop stress-ng
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/worker/memory_stress.sh"]

# OCI metadata
LABEL org.opencontainers.image.title="Module - Memory stress (stress-ng --memrate)" \
      org.opencontainers.image.description="Single-command Memory stress container with customizable parameters" \
      org.opencontainers.image.licenses="MIT"

