PROJECT := MenuBarBadger.xcodeproj
SCHEME := MenuBarBadger
DERIVED := build
WORKTREES := /Users/masa/Documents/repos/worktrees
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

.DEFAULT_GOAL := help
.PHONY: help build test install worktree

help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Debug flavor
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) -quiet build

test: ## Run the BadgerCore unit tests
	swift test --package-path Packages/BadgerCore

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
