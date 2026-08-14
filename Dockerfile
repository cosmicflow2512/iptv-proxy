FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /build

COPY go.mod go.sum ./
COPY vendor/ vendor/
COPY . .

ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -mod=vendor -ldflags="-s -w" -o iptv-proxy .

# The proxy writes its rewritten playlist to os.TempDir(), so the scratch image
# needs a /tmp. Staged here because scratch has no shell to mkdir with. COPY of a
# directory copies its contents with their metadata, not the directory itself, so
# stage it one level down to keep the 1777 mode.
RUN mkdir -p /scratch-root/tmp && chmod 1777 /scratch-root/tmp

FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /scratch-root/ /
COPY --from=builder /build/iptv-proxy /iptv-proxy

ENTRYPOINT ["/iptv-proxy"]
