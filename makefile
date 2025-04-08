.PHONY: all

pwd := $(shell pwd)
src_dir := $(pwd)
output_dir := $(pwd)/output
os := $(shell uname -s | tr '[:upper:]' '[:lower:]')

all: fonts build

submodules:
	@echo "Initializing Submodules..."
	@git submodule update --init --recursive || echo "\033[0;31m Error: Failed to initialize submodules"

fonts: submodules
	@echo "Download Fonts ..."
	@if [ "$(os)" = "darwin" ]; then \
		brew install --cask font-lora font-noto-serif-cjk-sc || echo "\033[0;31m Error: Failed to install fonts"; \
	else \
		bash ./scripts/download_fonts.sh || echo "\033[0;31m Error: Failed to download fonts"; \
	fi

build: submodules 
	@echo "Building..."
	@bash ./scripts/build_all_pdf.sh ${src_dir} ${output_dir} || echo "\033[0;31m Error: Failed to build PDF"

clean:
	@echo "Cleaning..."
	@bash ./scripts/clean.sh || echo "\033[0;31m Error: Failed to clean"