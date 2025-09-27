BIN := .venv/bin
PATH := $(BIN):$(PATH)
PIP := $(BIN)/python -m pip
PY := $(BIN)/python
export PATH := $(PATH)

requirements-all.yml:
	cat collections/requirements.yml roles/requirements.yml > ./requirements-all.yml

.venv: .tool-versions pyproject.toml
	asdf install python
	asdf install uv
	uv venv --seed --clear .venv
	uv sync
	make refresh-galaxy

.PHONY: init
init:
	rm -rf .venv
	make .venv

.PHONY: refresh-galaxy
refresh-galaxy: requirements-all.yml
	ansible-galaxy collection install -r collections/requirements.yml
	ansible-galaxy role install -r roles/requirements.yml

.PHONY: run-play
run-play: .venv requirements-all.yml
ifndef play
	echo "play=<path/to/play> argument is required"
	exit 1
endif
	$(BIN)/ansible-playbook -i inventory --diff -v $(args) $(play)
