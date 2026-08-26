FROM nginx:stable-alpine:3.24

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
