.PHONY: all

pwd := $(shell pwd)
src_dir := $(pwd)
output_dir := $(pwd)/output

all: fonts build

submodules:
	@echo "Initializing Submodules..."
	@git submodule update --init --recursive || echo "\033[0;31m Error: Failed to initialize submodules"

fonts: submodules
	@echo "Download Fonts ..."
	@bash ./scripts/download_fonts.sh || echo "\033[0;31m Error: Failed to download fonts"

build: submodules 
	@echo "Building..."
	@bash ./scripts/build_all_pdf.sh ${src_dir} ${output_dir} || echo "\033[0;31m Error: Failed to build PDF"

clean:
	@echo "Cleaning..."
	@git clean -f -X -d || echo "\033[0;31m Error: Failed to clean"
