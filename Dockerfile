FROM nginx:stable-alpine

RUN apk add --no-cache \
    bash \
    curl \
    htop \
    tcpdump \
    tcpflow \
    vim

USER nginx
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
