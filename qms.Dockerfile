# web/ui build stage
FROM node:6.9.1 AS node-build-env

ENV WEBUI_DIR /src/webui
RUN mkdir -p $WEBUI_DIR

RUN apt-get -yq update \
&& apt-get -yq --no-install-suggests --no-install-recommends --force-yes install apt-transport-https \
&& curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
&& echo "deb https://dl.yarnpkg.com/debian/ stable main" |  tee /etc/apt/sources.list.d/yarn.list \
&& apt-get -yq update && apt-get -yq --no-install-suggests --no-install-recommends --force-yes install yarn \
&& rm -fr /var/lib/apt/lists/

COPY webui/package.json $WEBUI_DIR/
COPY webui/yarn.lock $WEBUI_DIR/

WORKDIR $WEBUI_DIR
RUN npm set progress=false
RUN yarn install

COPY webui/. $WEBUI_DIR/
RUN npm run build

EXPOSE 8080

# server/go build stage
FROM golang:1.9.3-alpine3.6 AS go-build-env
RUN apk add --no-cache ca-certificates bash git openssh
RUN set -ex && apk add --no-cache --virtual .build-deps ca-certificates git

ENV GOPATH=/go
ENV PATH=$PATH:$GOPATH/bin

WORKDIR /go/src/github.com/containous/traefik
COPY . /go/src/github.com/containous/traefik
COPY --from=node-build-env /src/static /go/src/github.com/containous/traefik/static

RUN go get github.com/containous/go-bindata/...
RUN go generate

RUN /bin/sh ./script/binary


# final stage
FROM alpine
WORKDIR /app
COPY --from=go-build-env /go/src/github.com/containous/traefik/dist/traefik /app/
COPY --from=go-build-env /etc/ssl/certs/ /etc/ssl/certs/
ENTRYPOINT ["./traefik"]