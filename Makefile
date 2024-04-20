KUBERNETES_VERSION ?= 1.29.3
TALOS_VERSION ?= v1.6.7
CLUSTER_NAME ?= homelab
CONTROL_PLANE_URL ?= https://192.168.0.100:6443
CONTROL_PLANE ?= controlplane.yaml
WORKER ?= worker1.yaml

LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

TALOSCTL ?= $(LOCALBIN)/talosctl

.PHONY: all
all: help

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Install

.PHONY: talosctl
talosctl: ## Download talosctl locally if necessary.
ifeq (,$(wildcard $(TALOSCTL)))
ifeq (,$(shell which talosctl 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(TALOSCTL)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(TALOSCTL) https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-$${OS}-$${ARCH} ;\
	chmod +x $(TALOSCTL) ;\
	}
else
TALOSCTL = $(shell which talosctl)
endif
endif

# Image ID from https://factory.talos.dev/
IMAGE_ID?=f47e6cd2634c7a96988861031bcc4144468a1e3aef82cca4f5b5ca3fffef778a
.PHONY: image
image: ## Download talosctl locally if necessary.
	curl -LO https://factory.talos.dev/image/${IMAGE_ID}/v1.7.0/metal-arm64.raw.xz
	xz -d metal-arm64.raw.xz

##@ Generate

.PHONY: gen-secrets
gen-secrets: talosctl ## Generate secrets.
	$(TALOSCTL) gen secrets -o gen/secrets.yaml

.PHONY: gen-config
gen-config: talosctl ## Generate config.
	$(TALOSCTL) gen config $(CLUSTER_NAME) $(CONTROL_PLANE_URL) \
		--kubernetes-version $(KUBERNETES_VERSION) \
		--with-secrets gen/secrets.yaml \
		--config-patch-control-plane @config/$(CONTROL_PLANE) \
		-o gen

.PHONY: gen-worker
gen-worker: talosctl ## Generate worker config.
	$(TALOSCTL) machineconfig patch gen/worker.yaml \
		--patch @config/$(WORKER) \
		-o gen/$(WORKER) 