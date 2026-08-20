# Builds the COBOL "mainframe" binary that owns all banking business logic.
COBC ?= cobc
SRC_DIR := src
COPYBOOK_DIR := $(SRC_DIR)/copybooks
BIN_DIR := bin
DATA_DIR := data
OUT := $(BIN_DIR)/bank_api

# bank_api.cbl MUST be first: with multiple sources in one `cobc -x`
# invocation, the FIRST source file's PROGRAM-ID becomes the executable
# entry point; the rest are linked in as callable subprograms of the
# same binary (no separate .so modules are produced).
MAIN_SRC  := $(SRC_DIR)/bank_api.cbl
REPO_SRCS := $(wildcard $(SRC_DIR)/repository/*.cbl)
OP_SRCS   := $(wildcard $(SRC_DIR)/ops/*.cbl)
COPYBOOKS := $(wildcard $(COPYBOOK_DIR)/*.cpy)
SRCS      := $(MAIN_SRC) $(REPO_SRCS) $(OP_SRCS)

.PHONY: build clean

build: $(OUT) | $(DATA_DIR)

$(OUT): $(SRCS) $(COPYBOOKS) | $(BIN_DIR)
	$(COBC) -x -free -I$(COPYBOOK_DIR) $(SRCS) -o $(OUT)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(DATA_DIR):
	mkdir -p $(DATA_DIR)

clean:
	rm -f $(OUT)
	rm -rf $(BIN_DIR)
