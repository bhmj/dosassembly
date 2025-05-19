# build main app
ARG GOLANG_VERSION=1.24
ARG GOLANG_IMAGE=alpine
ARG TARGET_DISTR_TYPE
ARG TARGET_DISTR_VERSION

FROM golang:${GOLANG_VERSION}-${GOLANG_IMAGE} AS builder

ARG LDFLAGS
ARG GOOS=linux
ARG GOARCH=amd64

WORKDIR /source
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY internal/ ./internal/
RUN GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 go build -ldflags "$LDFLAGS" -trimpath -o bin/dosasm ./cmd/dosassembly

ARG TARGET_DISTR_TYPE
ARG TARGET_DISTR_VERSION
FROM ${TARGET_DISTR_TYPE}:${TARGET_DISTR_VERSION} AS dosasm
ARG USER
RUN adduser -Ds /bin/sh ${USER}
RUN apk update && apk add --no-cache bind-tools ca-certificates && update-ca-certificates
WORKDIR /app
COPY --from=builder /source/bin/dosasm .
ENTRYPOINT ["./dosasm"]
