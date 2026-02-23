# Dockerfile for dashboard-service
# This expects a Linux ARM64 binary in the same directory
FROM alpine:3.18

ENV PORT=9002
ENV COUNTING_SERVICE_URL=http://localhost:9003
WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Copy the Linux ARM64 binary
COPY dashboard-service .

EXPOSE ${PORT}

CMD ["./dashboard-service"]
