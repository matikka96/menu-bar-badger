PROJECT := MenuBarBadger.xcodeproj
SCHEME := MenuBarBadger
DERIVED := build
WORKTREES := /Users/masa/Documents/repos/worktrees
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

.DEFAULT_GOAL := help
.PHONY: help build test ui-test e2e install worktree

help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z0-9-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Debug flavor
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) -quiet build

test: ## Run the BadgerCore unit tests
	swift test --package-path Packages/BadgerCore

ui-test: ## Run the XCUITest flows of the settings window (takes the keyboard focus)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) \
		-destination platform=macOS CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) -quiet test

e2e: build ## Build the fixtures and run the e2e smoke scenarios (takes the keyboard focus)
	python3 -I E2E/run.py run

install: ## Build Release and replace /Applications/MenuBarBadger.app (clean main branch only)
	@Scripts/install.sh $(PROJECT) $(SCHEME) $(DERIVED) $(BUILD_NUMBER)

worktree: ## Create a worktree and a branch from dev: make worktree NAME=<name>
	@test -n "$(NAME)" || { echo "Give a name: make worktree NAME=<name>"; exit 1; }
	git worktree add $(WORKTREES)/menu-bar-badger-$(NAME) -b $(NAME) dev
	@for item in AGENTS.md .local Config/Local.xcconfig; do \
		if [ -e "$$item" ]; then mkdir -p "$(WORKTREES)/menu-bar-badger-$(NAME)/$$(dirname $$item)"; \
		cp -R "$$item" "$(WORKTREES)/menu-bar-badger-$(NAME)/$$item"; fi; \
	done
	@echo "Worktree: $(WORKTREES)/menu-bar-badger-$(NAME)"
