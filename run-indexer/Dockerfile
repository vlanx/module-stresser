# syntax=docker/dockerfile:1

FROM golang:1.25-alpine AS builder
WORKDIR /src

# If you have go.mod/go.sum in repo root (recommended)
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source
COPY . .

# Build a static binary
RUN CGO_ENABLED=0 GOOS=linux go build \
  -trimpath -ldflags="-s -w" \
  -o ./ \
  ./...

# Minimal runtime image
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /src/run-indexer /run-indexer
USER 10001:10001
ENTRYPOINT ["/run-indexer"]
