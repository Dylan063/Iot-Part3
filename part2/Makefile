.PHONY: h up down clean

h:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  up:        Start Vagrant machines"
	@echo "  down:      Destroy Vagrant machines"
	@echo "  clean:     Clean generated files"
	@echo "  h:         Show this help message"

up:
	@echo "Starting Vagrant machines..."
	vagrant up ihhadjalS

down:
	@echo "Destroying Vagrant machines..."
	vagrant destroy -f

clean:
	@echo "Cleaning generated files..."
	vagrant destroy -f
	rm -rf .vagrant