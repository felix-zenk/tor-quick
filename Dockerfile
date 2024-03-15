FROM alpine:latest

ENV PUBLIC_PORT=80
ENV FORWARD_ADDR=127.0.0.1:80

COPY init.sh /init.sh

RUN chmod +x /init.sh
RUN apk add tor
RUN chown -R root:root /var/lib/tor
RUN chmod -R 700 /var/lib/tor

ENTRYPOINT ["/init.sh"]

HEALTHCHECK --interval=10s --timeout=5s CMD ps -o comm | grep tor || exit 1
