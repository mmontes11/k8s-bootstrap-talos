KUBERNETES_VERSION ?= 1.30.0
TALOS_VERSION ?= v1.7.0
CLUSTER_NAME ?= homelab
CONTROLPLANE_URL ?= https://192.168.0.100:6443
CONTROLPLANE ?= controlplane.yaml
WORKER ?= worker1.yaml
NODE ?=

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

##@ Install - https://www.talos.dev/v1.7/talos-guides/install/single-board-computers/rpi_generic/

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
image: ## Download image.
	curl -LO https://factory.talos.dev/image/${IMAGE_ID}/v1.7.0/metal-arm64.raw.xz
	xz -d metal-arm64.raw.xz

##@ Generate

.PHONY: gen-secrets
gen-secrets: talosctl ## Generate secrets.
	$(TALOSCTL) gen secrets -o gen/secrets.yaml

.PHONY: gen-config
gen-config: talosctl ## Generate config.
	$(TALOSCTL) gen config $(CLUSTER_NAME) $(CONTROLPLANE_URL) \
		--kubernetes-version $(KUBERNETES_VERSION) \
		--with-secrets gen/secrets.yaml \
		--config-patch-control-plane @config/$(CONTROLPLANE) \
		-o gen --force

.PHONY: gen-worker
gen-worker: talosctl ## Generate worker config.
	$(TALOSCTL) machineconfig patch gen/worker.yaml \
		--patch @config/$(WORKER) \
		-o gen/$(WORKER)

##@ Apply

.PHONY: apply-controlplane
apply-controlplane: talosctl ## Apply controlplane config
	$(TALOSCTL) apply-config --insecure \
		-n $(NODE) \
		-f gen/$(CONTROLPLANE)

.PHONY: apply-worker
apply-worker: talosctl ## Apply worker config
	$(TALOSCTL) apply-config --insecure \
		-n $(NODE) \
		-f gen/$(WORKER)

##@ Bootstrap

.PHONY: bootstrap-k8s
bootstrap-k8s: talosctl ## Bootstrap kubernetes
	$(TALOSCTL) bootstrap -n $(NODE)

##@ Configuration

.PHONY: kubeconfig
kubeconfig: talosctl ## Get kubeconfig
	$(TALOSCTL) kubeconfig -n $(NODE)

.PHONY: talosconfig
talosconfig: talosctl ## Get talosconfig
	$(TALOSCTL) config merge gen/talosconfig