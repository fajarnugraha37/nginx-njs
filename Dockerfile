FROM nginx:1.28.0-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80
EXPOSE 443

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD nginx -t || exit 1

CMD ["nginx", "-g", "daemon off;"]
