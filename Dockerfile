FROM nginx:1.31.4-alpine

RUN apk add --no-cache \
    bash \
    curl \
    htop \
    tcpdump \
    tcpflow \
    libcap \
    vim

RUN setcap cap_net_raw+ep /usr/bin/tcpdump && \
    setcap cap_net_raw+ep /usr/bin/tcpflow

RUN rm -f /etc/nginx/conf.d/default.conf
RUN addgroup -g 1000 debian && adduser -D -u 1000 -G debian debian
RUN chown -R debian:debian /var/cache/nginx /var/log/nginx /var/run

USER debian
WORKDIR /home/debian
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
