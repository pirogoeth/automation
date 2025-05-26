SHELL := /bin/bash
.DEFAULT_GOAL := all

.PHONY: help
help: #> Show this help
help:
	@printf "\033[1mUsage: \033[0mmake [target]\n\n"
	@printf "\033[1m\033[33mtargets:\033[0m\n"
	@grep -E '^\S+:.*?#> .*' $(MAKEFILE_LIST) \
			| sort \
			| awk '\
					BEGIN {FS = ":.*?#> "}; \
					{printf "  \033[36m%-48s\033[0m %s\n", $$1, $$2} \
					'

.PHONY: upstream/ubuntu
upstream/ubuntu: #> Creates an Ubuntu template from a cloud-init-ready image
upstream/ubuntu:
	set -e ; \
	export \
		NODE=$(NODE) \
		VM_ID=$(VM_ID) \
		RELEASE=$(RELEASE) \
		SNAPSHOT=$(SNAPSHOT) \
		MACHINE_ARCH=$(MACHINE_ARCH) \
		TARGET_ISO_STORAGE=$(TARGET_ISO_STORAGE) \
		TARGET_VM_STORAGE=$(TARGET_VM_STORAGE) \
		CUSTOM_USER_CONFIG=$(CUSTOM_USER_CONFIG) \
		FORCE=$(FORCE) \
	&& { \
		set -e ; \
		[ -z "$${NODE}" ] && echo "need NODE=" && exit 127 ; \
		[ -z "$${VM_ID}" ] && echo "need VM_ID=" && exit 127 ; \
		[ -z "$${FORCE}" ] && export FORCE="-F" ; \
	} \
	&& ./scripts/create-ubuntu-template.sh \
		-i $${VM_ID} \
		-n $${NODE}
		-r $${RELEASE} \
		-s $${SNAPSHOT} \
		-m $${MACHINE_ARCH} \
		-t $${TARGET_ISO_STORAGE} \
		-T $${TARGET_VM_STORAGE} \
		-U $${CUSTOM_USER_CONFIG}
		$${FORCE}

manifests/packer-base.json: var_file ?= base.hcl
manifests/packer-base.json: #> Build a packer image+manifest for the Ubuntu template.
manifests/packer-base.json: ansible/play-base.yml ansible/roles/base/**/* ansible/inventory/group_vars/packer_*.yml
manifests/packer-base.json: packer/base.pkr.hcl packer/vars/$(var_file)
	mkdir -p manifests
	packer build \
		-var-file packer/vars/$(var_file) \
		$(args) \
		packer/base.pkr.hcl

manifests/packer-docker.json: var_file ?= docker.hcl
manifests/packer-docker.json: #> Build a packer image+manifest for the Docker template.
manifests/packer-docker.json: manifests/packer-base.json
manifests/packer-docker.json: ansible/play-docker.yml ansible/roles/docker/**/* ansible/inventory/group_vars/packer_*.yml
manifests/packer-docker.json: packer/docker.pkr.hcl packer/vars/$(var_file)
	mkdir -p manifests
	packer build \
		-var-file packer/vars/$(var_file) \
		-var "source_vm_id=$(shell scripts/get-last-run.sh manifests/packer-base.json)" \
		$(args) \
		packer/docker.pkr.hcl \
	|| rm manifests/packer-docker.json

manifests/packer-k3s.json: var_file ?= k3s.hcl
manifests/packer-k3s.json: #> Build a packer image+manifest for the K3s template.
manifests/packer-k3s.json: #> Parallelized builds are disabled here due to a race condition in the builder.
manifests/packer-k3s.json: manifests/packer-docker.json
manifests/packer-k3s.json: ansible/play-k3s.yml ansible/roles/k3s/**/* ansible/inventory/group_vars/packer_*.yml
manifests/packer-k3s.json: packer/k3s.pkr.hcl packer/vars/$(var_file)
	mkdir -p manifests
	packer build \
	 	-parallel-builds 1 \
		-var-file packer/vars/$(var_file) \
		-var "source_vm_id=$(shell scripts/get-last-run.sh manifests/packer-docker.json)" \
		$(args) \
		packer/k3s.pkr.hcl \
	|| rm manifests/packer-k3s.json

manifests/packer-buildkite.json: var_file ?= buildkite.hcl
manifests/packer-buildkite.json: #> Build a packer image+manifest for the Buildkite template.
manifests/packer-buildkite.json: manifests/packer-docker.json
manifests/packer-buildkite.json: ansible/playbooks/buildkite.yml ansible/roles/buildkite/**/* ansible/inventory/group_vars/packer_*.yml
manifests/packer-buildkite.json: packer/buildkite.pkr.hcl packer/vars/$(var_file)
	mkdir -p manifests
	packer build \
		-var-file packer/vars/$(var_file) \
		-var "source_vm_id=$(shell scripts/get-last-run.sh manifests/packer-docker.json)" \
		$(args) \
		packer/buildkite.pkr.hcl \
	|| rm manifests/packer-buildkite.json

.PHONY: all
all: manifests/packer-k3s.json
all: manifests/packer-buildkite.json

.PHONY: clean
clean: #> Clean up build artifacts.
clean:
	rm -rf manifests
