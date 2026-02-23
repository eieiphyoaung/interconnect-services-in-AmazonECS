# Dockerfile for counting-service
# This expects a Linux ARM64 binary in the same directory
FROM alpine:3.18

ENV PORT=9003
WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Copy the Linux ARM64 binary
COPY counting-service .

EXPOSE ${PORT}

CMD ["./counting-service"]
