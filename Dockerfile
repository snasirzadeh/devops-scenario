FROM nginxinc/nginx-unprivileged:1.31.3-alpine

USER root

RUN apk add --no-cache \
    bash \
    curl \
    htop \
    tcpdump \
    tcpflow \
    vim \
    && rm -rf /var/cache/apk/*

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
