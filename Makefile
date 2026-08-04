PYTHON ?= python3

LINODE_SDK_VERSION ?= "0.0.0.dev"
INTEGRATION_DIR := ./test/integration
CASSETTE_DIR := ./test/cassettes
VERSION_MODULE_DOCSTRING ?= \"\"\"\nThe version of this linode_api4 package.\n\"\"\"\n\n
VERSION_FILE := ./linode_api4/version.py

.PHONY: clean
clean:
	mkdir -p dist
	rm -r dist
	rm -f baked_version

.PHONY: build
build: clean create-version
	$(PYTHON) -m build  --wheel --sdist

.PHONY: create-version
create-version:
	@printf "${VERSION_MODULE_DOCSTRING}__version__ = \"${LINODE_SDK_VERSION}\"\n" > $(VERSION_FILE)

.PHONY: release
release: build
	$(PYTHON) -m twine upload dist/*

.PHONY: dev-install
dev-install: clean
	$(PYTHON) -m pip install -e ".[dev]"

.PHONY: install
install: clean create-version
	$(PYTHON) -m pip install .

.PHONY: black
black:
	$(PYTHON) -m black linode_api4 test

.PHONY: isort
isort:
	$(PYTHON) -m isort linode_api4 test

.PHONY: autoflake
autoflake:
	$(PYTHON) -m autoflake linode_api4 test

.PHONY: format
format: black isort autoflake

.PHONY: lint
lint: build
	$(PYTHON) -m isort --check-only linode_api4 test
	$(PYTHON) -m autoflake --check linode_api4 test
	$(PYTHON) -m black --check --verbose linode_api4 test
	$(PYTHON) -m pylint linode_api4
	$(PYTHON) -m twine check dist/*

# Integration Test Arguments
# TEST_SUITE: Optional, specify a test suite (e.g. domain), Default to run everything if not set
# TEST_CASE: Optional, specify a test case (e.g. 'test_image_replication')
# TEST_ARGS: Optional, additional arguments for pytest (e.g. '-v' for verbose mode)

TEST_COMMAND = $(if $(TEST_SUITE),$(if $(filter $(TEST_SUITE),linode_client login_client filters),$(TEST_SUITE),models/$(TEST_SUITE)))

.PHONY: test-int
test-int:
# 	$(PYTHON) -m pytest test/integration/${TEST_COMMAND} $(if $(TEST_CASE),-k $(TEST_CASE)) ${TEST_ARGS}
#   record-mode=none -> This is used to run the tests without recording new cassettes. It will use the existing cassettes for the tests.
	$(PYTHON) -m pytest test/integration/${TEST_COMMAND} $(if $(TEST_CASE),-k $(TEST_CASE)) ${TEST_ARGS} --record-mode=none

.PHONY: test-unit
test-unit:
	$(PYTHON) -m pytest test/unit

.PHONY: test-smoke
test-smoke:
# 	$(PYTHON) -m pytest -m smoke test/integration
#   record-mode=all -> This is used to run the tests and record new cassettes. It will overwrite the existing cassettes for the tests.
	$(PYTHON) -m pytest -m smoke test/integration --record-mode=all

run_cassettes:
#   record-mode=all -> This is used to run the tests and record new cassettes. It will overwrite the existing cassettes for the tests.
	@echo "Running cassettes..."
	$(PYTHON) -m pytest test/integration/${TEST_COMMAND} $(if $(TEST_CASE),-k $(TEST_CASE)) ${TEST_ARGS} --record-mode=all

sanitize:
	@echo "Sanitizing cassettes..."
	@for yaml in $(CASSETTE_DIR)/*yaml; do \
		sed -E -i.bak \
			-e 's_stats/20[0-9]{2}/[1-9][0-2]?_stats/2018/1_g' \
			-e 's/(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/1234::5678/g' \
			-e 's/((25[0-5]|(2[0-4]|1[0-9]|[1-9])[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9])[0-9])/192.0.2.0/g' \
			-e 's/"root_pass":"[^"]*"/"root_pass":"thisIsYourRootPassword"/g' \
			-e 's/"hostname": *"[^"]*"/"hostname":"thisIsYourHostName"/g' \
			$$yaml; \
	done
	@find $(CASSETTE_DIR) -name *yaml.bak -exec rm {} \;

.PHONY: cassettes
cassettes: run_cassettes sanitize