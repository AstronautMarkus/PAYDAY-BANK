# Orchestrates the two layers of the project:
#   core/   the COBOL "mainframe" (compiled with GNU COBOL)
#   client/ the Flask web client (talks to core via subprocess)
VENV := .venv
PYTHON := $(VENV)/bin/python

.PHONY: setup build-core run-client clean

setup: $(VENV) build-core
	$(VENV)/bin/pip install -r client/requirements.txt

$(VENV):
	python3 -m venv $(VENV)

build-core:
	$(MAKE) -C core build

run-client:
	cd client && ../$(PYTHON) wsgi.py

clean:
	$(MAKE) -C core clean
	rm -rf $(VENV)
