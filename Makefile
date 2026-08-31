# KENOS — canonical commands (see CONTRIBUTING.md for the full picture)
.DEFAULT_GOAL := help
.PHONY: help dev dev-cloud analyze test test-cloud test-coverage build-web deploy-web serve-web db-start db-reset db-test db-push e2e gen-icons gen-audio coverage

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

coverage: ## Generate test coverage report (LCOV format)
	@dart pub global activate coverage
	@flutter test --coverage
	@dart pub global activate lcov
	@lcov --remove coverage/lcov.info -o coverage/lcov.info 'lib/main.dart' '**.g.dart' '**.config.dart'
	@genhtml coverage/lcov.info -o coverage/html --quiet
	@echo "Coverage report generated: open coverage/html/index.html"

test-cloud: ## Real-ether smoke test (seal → escrow → decrypt); needs .env.cloud
	@touch .env.cloud
	flutter test test/cloud_smoke_test.dart $$(grep -v '^#' .env.cloud | sed 's/^/--dart-define=/' | tr '\n' ' ')

build-web: ## Release web build (compiles the fragment shader)
	flutter build web --release

deploy-web: ## Build for the real ether and deploy the PWA to Vercel (prod)
	@touch .env.cloud
	flutter build web --release $$(grep -v '^#' .env.cloud | sed 's/^/--dart-define=/' | tr '\n' ' ')
	@# Deploy FROM build/web (the documented static path): the root link
	@# state travels with the copied .vercel so nothing else uploads.
	rm -rf build/web/.vercel && cp -R .vercel build/web/.vercel
	cd build/web && vercel deploy --prod --yes
	@# Build gate: the web pickers MUST be in the bundle. A poisoned
	@# incremental cache once shipped a bundle without them — the buttons
	@# then hung silently forever. If this fails: flutter clean && retry.
	@grep -q getUserMedia build/web/main.dart.js \
		&& echo "build sane: web pickers present" \
		|| (echo "BROKEN BUILD CACHE - run: flutter clean && make deploy-web" && exit 1)
	@# Post-deploy gate: the domain MUST serve the app (it once silently
	@# served an empty redeploy). Fails the target if not.
	@sleep 5; curl -fsS -o /dev/null https://kenos-lemon.vercel.app/main.dart.js \
		&& echo "production verified: main.dart.js 200" \
		|| (echo "PRODUCTION BROKEN - redeploy" && exit 1)

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
