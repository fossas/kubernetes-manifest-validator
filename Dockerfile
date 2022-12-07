# The shasum used should be one tied to the tag, not the architecture.
# Source: https://github.com/clusterkit/tools/pkgs/container/tools/
FROM ghcr.io/clusterkit/tools:1.25.4@sha256:f75d51e7f6aae2488ed3163cde8d78c0ba6bb10ba58074821b7628e6dd1cb0c5
COPY validate.sh /validate.sh
ENTRYPOINT ["bash", "/validate.sh"]
