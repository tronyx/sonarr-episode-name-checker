#FROM lsiobase/alpine:3.11
FROM ghcr.io/organizr/base

LABEL maintainer="tronyx"

# Add local files
COPY ./ /app
WORKDIR /app

# Install packages
#RUN apk add --no-cache \
#	nodejs-npm \
#	nodejs-current \
#	&& npm install

CMD sh /app/SonarrEpisodeNameChecker.sh