FROM alpine:latest

RUN apk update
RUN apk upgrade
RUN apk add tor

COPY init.sh /init.sh
RUN chmod +x /init.sh

CMD ["/init.sh"]

HEALTHCHECK --interval=10s --timeout=5s CMD ps -o comm | grep tor || exit 1
