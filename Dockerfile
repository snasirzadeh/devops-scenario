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
RUN mkdir -p /home/nginx && chown -R nginx:nginx /home/nginx /var/cache/nginx /var/log/nginx

USER nginx
WORKDIR /home/nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
