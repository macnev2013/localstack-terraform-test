#!/bin/bash

VENV_BIN ?= python3 -m venv
VENV_DIR ?= .venv
PIP_CMD ?= pip3

ifeq ($(OS), Windows_NT)
	VENV_ACTIVATE = $(VENV_DIR)/Scripts/activate
else
	VENV_ACTIVATE = $(VENV_DIR)/bin/activate
endif

usage:						## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/:.*##\s*/##/g' | awk -F'##' '{ printf "%-25s %s\n", $$1, $$2 }'

$(VENV_ACTIVATE):
	test -d $(VENV_DIR) || $(VENV_BIN) $(VENV_DIR)
	$(VENV_RUN); $(PIP_CMD) install --upgrade pip setuptools wheel plux
	touch $(VENV_ACTIVATE)

VENV_RUN = . $(VENV_ACTIVATE)

venv: $(VENV_ACTIVATE)		## Create a new (empty) virtual environment

install:					## Install the package in editable mode
	$(VENV_RUN); $(PIP_CMD) install -r requirements.txt

init-precommit:				## install the pre-commit hook into your local git repository
	($(VENV_RUN); pre-commit install)

lint:						## Run linting
	@echo "Running black... "
	black --check .

format:						## Run formatting
	$(VENV_RUN); python -m isort .; python -m black .
