FROM alpine:3.21

# Install dependencies
RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        device-mapper \
        thin-provisioning-tools \
        zfs \
        wget && \
    rm -rf /var/cache/apk/*

# Download and install cAdvisor binary from official release
RUN wget -O /usr/bin/cadvisor https://github.com/google/cadvisor/releases/download/v0.49.1/cadvisor-v0.49.1-linux-amd64 && \
    chmod +x /usr/bin/cadvisor

# Expose cAdvisor default port
EXPOSE 8080

# Run cAdvisor
ENTRYPOINT ["/usr/bin/cadvisor"]
CMD ["-logtostderr"]
