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
	@echo "test               Run every Molecule scenario, one scenario at a time"
	@echo "test-<scenario>    Run one Molecule scenario: $(SCENARIOS)"
	@echo "                   SERIAL=1 runs each scenario once per platform, so only one VM is up at a time"
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
ifdef SERIAL
	set -e; for s in $(SCENARIOS); do $(MAKE) test-$$s; done
else
	molecule test --all
endif

# Phony targets skip pattern rules, so spell out test-<scenario> with a static pattern rule
# SERIAL=1: the whole sequence (create to destroy) once per platform, for hosts that can't fit a scenario's VMs at once
$(SCENARIO_TESTS): test-%:
ifdef SERIAL
	set -e; for p in $$(molecule list -s $* -f plain 2>/dev/null | awk '{print $$1}'); do molecule test -s $* -p $$p; done
else
	molecule test -s $*
endif

destroy:
	molecule destroy --all

build:
	ansible-galaxy collection build --force

clean:
	rm -f afmigoo-selfhosted-*.tar.gz
