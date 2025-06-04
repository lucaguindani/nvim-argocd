# Makefile

# Define the base Neovim command for testing
NVIM_FLAGS = --headless --noplugin
MINIMAL_INIT = tests/minimal_init.lua
TEST_DIR = lua/tests

# Run all tests
test:
	@echo "Running all tests..."
	@nvim $(NVIM_FLAGS) -u $(MINIMAL_INIT) -c "PlenaryBustedDirectory $(TEST_DIR) {minimal_init = '$(MINIMAL_INIT)'}"
