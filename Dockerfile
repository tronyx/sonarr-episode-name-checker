ARG BASE_IMAGE
ARG ARCH
FROM ${BASE_IMAGE:-ghcr.io/organizr/base:2021-02-13_19}-${ARCH:-linux-amd64}

LABEL maintainer="tronyx"

# Add local files
COPY ./ /app
WORKDIR /app

CMD sh /app/SonarrEpisodeNameChecker.sh