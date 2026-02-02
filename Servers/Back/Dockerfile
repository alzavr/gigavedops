FROM gcr.io/distroless/base-debian12

WORKDIR /app
COPY backend-api /app/backend-api
COPY config.yaml /etc/backend-api/config.yaml

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/backend-api"]