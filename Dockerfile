FROM --platform=$TARGETPLATFORM alpine:latest

RUN apk --no-cache upgrade
RUN apk add tor git python3 py3-stem
RUN git clone -q https://github.com/mikeperry-tor/vanguards.git /opt/vanguards
RUN chown -R tor:nogroup /opt/vanguards

COPY healthcheck.sh /healthcheck.sh
COPY init.sh /init.sh
RUN chmod +x /healthcheck.sh /init.sh

CMD ["/init.sh"]

HEALTHCHECK --interval=2s --timeout=1s --start-period=10s CMD /healthcheck.sh
