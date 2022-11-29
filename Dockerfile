FROM alpine:3
COPY validate.sh /validate.sh
COPY setup.sh /setup.sh
RUN sh /setup.sh
RUN chmod +x /validate.sh
ENTRYPOINT ["/validate.sh"]
