# KENOS — canonical commands (see CONTRIBUTING.md for the full picture)
.DEFAULT_GOAL := help
.PHONY: help dev dev-cloud analyze test build-web serve-web db-start db-reset db-test db-push e2e gen-icons gen-audio

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

dev: ## Run the app (demo mode without credentials)
	flutter run

dev-cloud: ## Run the app on the real ether (.env.cloud required)
	@touch .env.cloud
	flutter run $$(grep -v '^#' .env.cloud | sed 's/^/--dart-define=/' | tr '\n' ' ')

analyze: ## Static analysis (must be 0 issue)
	flutter analyze

test: ## Dart test suite
	flutter test

build-web: ## Release web build (compiles the fragment shader)
	flutter build web --release

serve-web: build-web ## Serve the built PWA on :4308
	cd build/web && python3 -m http.server 4308

db-start: ## Start the local Supabase stack (ports 56321-56324)
	supabase start

db-reset: ## Recreate the local database from the migrations
	supabase db reset

db-test: ## pgTAP suite: 48 SQL invariants (RPC + RLS)
	supabase test db

db-push: ## Push unapplied migrations to the linked cloud project
	supabase db push

e2e: ## Full bottle-in-the-sea loop over the real local PostgREST
	bash scripts/e2e_local.sh

gen-icons: ## Regenerate Web/Android/iOS icons (stdlib only)
	python3 tool/gen_icons.py

gen-audio: ## Regenerate the synthesized audio assets (stdlib only)
	python3 tool/gen_audio.py
