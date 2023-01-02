FROM node:latest AS build-js

RUN npm install gulp gulp-cli -g

RUN git clone https://github.com/stevesec/gophish /build
WORKDIR /build
COPY . .
RUN npm install --only=dev
RUN gulp

# Build Golang binary
FROM golang:1.15.2 AS build-golang

RUN git clone https://github.com/stevesec/gophish /go/src/github.com/stevesec/gophish
WORKDIR /go/src/github.com/stevesec/gophish
RUN go get -v && go build -v

# Runtime container
FROM debian:stable-slim

ENV GITHUB_USER="stevesec"
ENV GOPHISH_REPOSITORY="github.com/${GITHUB_USER}/gophish"
ENV PROJECT_DIR="${GOPATH}/src/${GOPHISH_REPOSITORY}"

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="v0.0.1"

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
	apt-get install --no-install-recommends -y jq libcap2-bin && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish
COPY --from=build-golang /go/src/github.com/stevesec/gophish/ ./
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /go/src/github.com/stevesec/gophish/config.json ./
COPY ./docker-entrypoint.sh /opt/gophish
RUN chmod +x /opt/gophish/docker-entrypoint.sh
RUN chown app. config.json docker-entrypoint.sh


RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app
RUN touch config.json.tmp

EXPOSE 3333 8080

CMD ["/opt/gophish/docker-entrypoint.sh"]

STOPSIGNAL SIGKILL

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="Gophish Docker" \
  org.label-schema.description="Gophish Docker Build" \
  org.label-schema.url="https://github.com/stevesec/docker-gophish" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/stevesec/docker-gophish" \
  org.label-schema.vendor="stevesec" \
  org.label-schema.version=$VERSION \
  org.label-schema.schema-version="1.0"
