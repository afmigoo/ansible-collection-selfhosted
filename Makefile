# Shortcuts for development tasks. Run inside the afmigoo.selfhosted env (see .python-version; a project .venv works too).
# None of the targets build files, so all of them are phony.
SCENARIOS := $(notdir $(patsubst %/molecule.yml,%,$(wildcard extensions/molecule/*/molecule.yml)))
SCENARIO_TESTS := $(addprefix test-,$(SCENARIOS))

.DEFAULT_GOAL := help
.PHONY: help install lint syntax test $(SCENARIO_TESTS) destroy build clean

help:
	@echo "install            Install Python packages and Ansible collections"
	@echo "lint               Run ansible-lint (includes yamllint)"
	@echo "syntax             Syntax-check every Molecule scenario"
	@echo "test               Run every Molecule scenario, one VM at a time"
	@echo "test-<scenario>    Run one Molecule scenario: $(SCENARIOS)"
	@echo "destroy            Destroy VMs left over from interrupted Molecule runs"
	@echo "build              Build the collection tarball"
	@echo "clean              Remove built tarballs"

install:
	pip install -r requirements.txt
	ansible-galaxy collection install -r extensions/molecule/requirements.yml
	ansible-galaxy collection install -r requirements.yml

lint:
	ansible-lint

syntax:
	molecule syntax --all

test:
	molecule test --all

# Phony targets skip pattern rules, so spell out test-<scenario> with a static pattern rule
$(SCENARIO_TESTS): test-%:
	molecule test -s $*

destroy:
	molecule destroy --all

build:
	ansible-galaxy collection build --force

clean:
	rm -f afmigoo-selfhosted-*.tar.gz
