# The shasum used should be one tied to the tag, not the architecture.
# Source: https://github.com/clusterkit/tools/pkgs/container/tools/
# FROM ghcr.io/clusterkit/tools:1.25.4@sha256:f75d51e7f6aae2488ed3163cde8d78c0ba6bb10ba58074821b7628e6dd1cb0c5
FROM ghcr.io/fossas/clustertoolkit:1.25.4
COPY validate.sh /validate.sh

# make a runner user for github actions compatibility
USER root
RUN adduser --disabled-password --gecos "" runner
USER runner
WORKDIR /home/runner

ENTRYPOINT ["bash", "/validate.sh"]
