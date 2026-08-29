FROM nginx:stable-alpine

RUN apk add --no-cache \
    bash \
    curl \
    htop \
    tcpdump \
    tcpflow \
    vim
RUN rm -f /etc/nginx/conf.d/default.conf
RUN addgroup -g 1000 debian && adduser -D -u 1000 -G debian debian
RUN chown -R debian:debian /var/cache/nginx /var/log/nginx /var/run

USER debian
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
