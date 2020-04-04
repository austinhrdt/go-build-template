# Make file to build & publish binaries & containers

# The binaries to build.
BINS := app1 app2

# Where to push the docker image.
REGISTRY ?= ahardt013

# The version
VERSION ?= $(shell cat version)

# directories which hold app source (not vendored)
SRC_DIRS := cmd pkg

# Used internally.  Users should pass GOOS and/or GOARCH.
OS := $(if $(GOOS),$(GOOS),$(shell go env GOOS))
ARCH := $(if $(GOARCH),$(GOARCH),$(shell go env GOARCH))

# Directory structure of output binaries
OUTBINS := $(foreach bin, $(BINS), bin/$(OS)_$(ARCH)/$(bin))

# Image in which to place binaries.
BASEIMAGE ?= gcr.io/distroless/static

# Tag of our docker images.
TAG := $(VERSION)__$(OS)_$(ARCH)

# For the following OS/ARCH expansions, we transform OS/ARCH into OS_ARCH
# because make pattern rules don't match with embedded '/' characters.

build-%:
	@$(MAKE) build                        \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

container-%:
	@$(MAKE) container                    \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

push-%:
	@$(MAKE) push                         \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

publish-%:
	@$(MAKE) publish                      \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

.PHONY: build
build:
	@$(foreach trig, $(OUTBINS), $(MAKE) -s $(trig);)

# Directories that we need created to build/test.
BUILD_DIRS := bin/$(OS)_$(ARCH)     \
              .go/bin/$(OS)_$(ARCH)

# The following structure defeats Go's (intentional) behavior to always touch
# result files, even if they have not changed.  This will still run `go` but
# will not trigger further work if nothing has actually changed.
bin/$(OS)_$(ARCH)/%:
	@$(MAKE) -s .go/$@.stamp

# This will build the binary under ./.go and update the real binary iff needed.
.PHONY: .go/%.stamp
.go/%.stamp: $(BUILD_DIRS)
	@echo ? Building $*
	@ARCH=$(ARCH) OS=$(OS) VERSION=$(VERSION) ./build/build.sh
	@if ! cmp -s .go/$* $*; then 							\
	    mv .go/$* $*;           						    \
	    date >$@;											\
	fi

.PHONY: container
container: build
	@$(foreach trig, $(BINS), $(MAKE) -s .container-$(trig);)

# This will build container for each binary
.container-%: Dockerfile.in
	@echo ? Containerizing $*
	@sed                                 \
	    -e 's|{ARG_BIN}|$*|g'        \
	    -e 's|{ARG_ARCH}|$(ARCH)|g'      \
	    -e 's|{ARG_OS}|$(OS)|g'          \
	    -e 's|{ARG_FROM}|$(BASEIMAGE)|g' \
	    Dockerfile.in > .dockerfile-$*-$(OS)_$(ARCH)
	@docker build -t $(REGISTRY)/$*:$(TAG) -f .dockerfile-$*-$(OS)_$(ARCH) .
	@docker build -t $(REGISTRY)/$*:latest -f .dockerfile-$*-$(OS)_$(ARCH) .
	@docker images -q $(REGISTRY)/$*:$(TAG) > $@-$(TAG)
	@docker images -q $(REGISTRY)/$*:latest > $@-latest

.PHONY: push
push: container
	@$(foreach trig, $(BINS), $(MAKE) -s .push-$(trig);)

# This will push latest image to registry
.push-%:
	@echo ? Pushing $*
	@docker push $(REGISTRY)/$*:latest

.PHONY: publish
publish: push
	@$(foreach trig, $(BINS), $(MAKE) -s .publish-$(trig);)

# This will publish image to registry
.publish-%:
	@echo ? Publishing $*
	@docker push $(REGISTRY)/$*:$(TAG)

test: $(BUILD_DIRS)
	@ARCH=$(ARCH) OS=$(OS) VERSION=$(VERSION) ./build/test.sh $(SRC_DIRS) | tee .go/.test_results

$(BUILD_DIRS):
	@mkdir -p $@

clean: container-clean bin-clean

container-clean:
	rm -rf .container-* .dockerfile-*

bin-clean:
	rm -rf .go bin
