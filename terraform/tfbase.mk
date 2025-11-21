TF := tofu

ENVFILE := $(shell mu find-upwards .env)
VARSDIR := ../vars
include $(ENVFILE)
export

all: plan

plan: *.tf
ifdef target
	$(TF) plan -var-file $(VARSDIR)/$(VARS_NAME).tfvars -out plan -target "$(target)" $(args) || rm plan
else
	$(TF) plan -var-file $(VARSDIR)/$(VARS_NAME).tfvars -out plan $(args) || rm plan
endif

.PHONY: apply
apply: plan
	$(TF) apply plan
	rm plan

.PHONY: reinit-modules
reinit-modules:
	$(TF) init -upgrade -var-file $(VARSDIR)/$(VARS_NAME).tfvars

.PHONY: clean
clean:
	rm plan

.PHONY: upgrade
upgrade:
	$(TF) init --upgrade -var-file $(VARSDIR)/$(VARS_NAME).tfvars

.PHONY: console
console:
	$(TF) console -var-file $(VARSDIR)/$(VARS_NAME).tfvars

.PHONY: outputs
outputs:
	$(TF) output --json | jq .
