# Shared stencil driver for every .config.yaml in this repository.
#
# Each config directory's Makefile is two lines -- a CONFIG, and an include of
# this file -- so there is one copy of these targets rather than one per
# directory. The copies had already drifted: assignments/ was still calling
# `stencil --list` and `stencil <pkg> --dry-run`, a CLI spelling the tool
# stopped using, while classroom/ was current.
#
# Usage, from any config directory:
#   make install                  # Install stencil and set up .gitignore
#   make reinstall                # Reinstall the newest stencil release
#   make reinstall REF=42         # Reinstall from PR #42 (URL, branch or sha also work)
#   make gen P=poster             # Generate scaffolding
#   make gen-dry P=poster         # Preview what would be generated
#   make list                     # List available packages

# The repository root: the directory this file sits in, as spelled by whoever
# included it. At the moment this line is parsed, MAKEFILE_LIST ends with this
# file, so `dir` of it is the root -- ".." from a config directory, "." from
# the root's own Makefile.
#
# Deliberately not `git rev-parse --show-toplevel`, which has nothing to answer
# in an export with no .git, and deliberately not a walk up for
# requirements.txt: a subdirectory holding a different tool may have one of its
# own, and the walk would stop there. cs425/facebooks is exactly that -- jinja2
# and pyyaml behind its own render.py, no stencil in it.
#
# This file is meant to be identical in every repository that uses stencil, so
# that keeping them in step is a copy rather than a merge.
ROOT := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

PYTHON = python3
# One virtualenv for the whole repository. Every config directory drove its own
# before this, so `make reinstall` in one left the others on whatever stencil
# they were last given -- four venvs on three different builds, at one point.
VENV = $(ROOT)/.venv
VENV_PIP = $(VENV)/bin/pip
REQUIREMENTS = $(ROOT)/requirements.txt

# The config directory's own file. Set by the including Makefile.
CONFIG ?= .config.yaml
STENCIL = $(VENV)/bin/stencil --config $(CONFIG)

# What this directory calls the things it generates, for the help text only.
UNIT ?= package

# Where `make reinstall REF=...` fetches stencil from.
STENCIL_REPO ?= https://github.com/grimwm/stencil.git

.PHONY: help list install stencil-version reinstall clean clean-venv gen gen-dry

help: ## Show this help message
	@echo "Usage: make <target> [P=<$(UNIT)>]"
	@echo ""
	@echo "Targets:"
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""
	@echo "Variable P ($(UNIT) name):"
	@echo "  gen / gen-dry:  Omit P to generate (or preview) ALL $(UNIT)s; set P=<name> to act on one. Run 'make list' for names."
	@echo "  clean:          Omit P to remove ALL generated scaffolding; set P=<name> to remove one only. Does NOT remove the venv."
	@echo "  clean-venv:     Removes $(VENV), which EVERY config directory in this repo shares."

list: $(VENV)/bin/activate ## List available packages
	@$(STENCIL) list

install: $(VENV)/bin/activate ## Install stencil and set up .gitignore
	@if [ -f '$(CONFIG)' ]; then $(STENCIL) install; else echo "Skipping stencil install (no $(CONFIG) in this directory)"; fi

reinstall: $(VENV)/bin/activate ## Reinstall the newest stencil release (REF=<pr#|url|branch|sha> to pin)
ifdef REF
	@spec='$(REF)'; \
	case "$$spec" in \
	  */pull/*)    n=$${spec##*/pull/}; spec="refs/pull/$${n%%/*}/head" ;; \
	  ''|*[!0-9]*) ;; \
	  *)           spec="refs/pull/$$spec/head" ;; \
	esac; \
	echo "Installing stencil from $$spec into $(VENV)"; \
	$(VENV_PIP) install --force-reinstall "stencil @ git+$(STENCIL_REPO)@$$spec"
else
	$(VENV)/bin/stencil update --yes
endif
	@if [ -f '$(CONFIG)' ]; then $(STENCIL) install; else echo "Skipping stencil install (no $(CONFIG) in this directory)"; fi

stencil-version: $(VENV)/bin/activate ## Show which stencil build is installed
	@$(VENV_PIP) freeze 2>/dev/null | grep -i '^stencil' || echo "stencil is not installed in $(VENV)"

$(VENV)/bin/activate: $(REQUIREMENTS)
	$(PYTHON) -m venv $(VENV)
	$(VENV_PIP) install --upgrade pip
	$(VENV_PIP) install -r $(REQUIREMENTS)
	touch $(VENV)/bin/activate

clean: ## Remove generated scaffolding (use P=<name> for one; does not remove the venv)
ifndef P
	$(STENCIL) clean --all
else
	$(STENCIL) clean $(P)
endif

clean-venv: ## Remove the shared virtualenv (every config directory uses it)
	rm -rf $(VENV)

gen: install ## Generate scaffolding (omit P for all, or P=<name> for one)
ifndef P
	@$(STENCIL) gen --all
else
	$(STENCIL) gen $(P)
endif

gen-dry: install ## Preview what would be generated (requires P=<name>)
ifndef P
	@echo "Usage: make gen-dry P=<$(UNIT)>"
	@echo ""
	@$(STENCIL) list
else
	$(STENCIL) gen $(P) --dry-run
endif
