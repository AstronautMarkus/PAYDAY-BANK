# Builds the COBOL "mainframe" binary that owns all banking business logic.
COBC ?= cobc
SRC := src/bank_api.cbl
BIN_DIR := bin
DATA_DIR := data
OUT := $(BIN_DIR)/bank_api

.PHONY: build clean

build: $(OUT) | $(DATA_DIR)

$(OUT): $(SRC) | $(BIN_DIR)
	$(COBC) -x -free $(SRC) -o $(OUT)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(DATA_DIR):
	mkdir -p $(DATA_DIR)

clean:
	rm -f $(OUT)
	rm -rf $(BIN_DIR)
