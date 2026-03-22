# Makefile for building and installing Qwen Code project

.PHONY: all build install clean

# Default target
all: build install

# Build target – invokes the build.sh script
# Pass additional options via BUILD_OPTS variable, e.g., make build BUILD_OPTS="--no-helm"
build:
	@./build.sh $(BUILD_OPTS)

# Install target – invokes the install.sh script
install:
	@./install.sh

# Clean target – placeholder for any cleanup steps if needed in the future
clean:
	@echo "No clean steps defined."
