# Makefile for Ada Lamport Bakery Algorithm

.PHONY: all clean test run

# Default target
all: build

# Build the main bakery program
build:
	mkdir -p obj bin
	gnatmake -P bakery.gpr

# Build and run tests
test: build-tests run-tests

build-tests:
	mkdir -p obj bin
	gnatmake -P tests/bakery_tests.gpr

run-tests: build-tests
	./bin/bakery_tests

# Run the main program
run: build
	./bin/bakery

# Clean build artifacts
clean:
	rm -rf obj bin

# Rebuild everything
rebuild: clean all
