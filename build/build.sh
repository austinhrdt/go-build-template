#!/bin/sh

set -o errexit
set -o nounset

if [ -z "${OS:-}" ]; then
    echo "OS must be set"
    exit 1
fi
if [ -z "${ARCH:-}" ]; then
    echo "ARCH must be set"
    exit 1
fi
if [ -z "${VERSION:-}" ]; then
    echo "VERSION must be set"
    exit 1
fi

export CGO_ENABLED=0
export GOARCH="${ARCH}"
export GOOS="${OS}"
export GO111MODULE=on
export GOFLAGS="-mod=vendor"

go build                                                        \
    -o "${PWD}/.go/bin/${OS}_${ARCH}"                           \
    -installsuffix "static"                                     \
    -ldflags "-X $(go list -m)/pkg/version.Version=${VERSION}"  \
    ./...
