# KENOS — canonical commands (see CONTRIBUTING.md for the full picture)
.DEFAULT_GOAL := help
.PHONY: help dev dev-cloud dev-local analyze test test-cloud test-coverage build-web deploy-web deploy-site serve-web db-start db-reset db-test db-push db-seed-load db-verify-load db-load-report db-wipe-load db-garden db-curate db-sow-vestiges prod-reset prod-sow e2e gen-icons gen-audio coverage

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

dev: ## Run the app (demo mode without credentials)
	flutter run

dev-cloud: ## Run the app on the real ether (.env.cloud required)
	@touch .env.cloud
	flutter run $$(grep -v '^#' .env.cloud | sed 's/^/--dart-define=/' | tr '\n' ' ')

dev-local: ## Run the app on the LOCAL seeded ether (release PWA, :4308)
	flutter build web --release \
		--dart-define=SUPABASE_URL=$$(supabase status -o env | sed -n 's/.*API_URL=//p' | tr -d '"') \
		--dart-define=SUPABASE_ANON_KEY=$$(supabase status -o env | sed -n 's/.*ANON_KEY=//p' | tr -d '"')
	@# Perf is judged on RELEASE builds only — `flutter run` is debug
	@# (5-20× slower) and will always feel broken under volume.
	python3 tool/serve_web.py 4308

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
	@# NB: this rebuilds build/web with PROD credentials — the :4308
	@# server then serves the real ether. Run `make dev-local` after a
	@# deploy to restore the local-ether build on :4308.
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

serve-web: build-web ## Serve the built PWA on :4308 (no-cache dev server)
	python3 tool/serve_web.py 4308

deploy-site: ## Deploy the landing (kenos-site) + pin the production alias
	@# The alias assignment at deploy time is a known race (it lost
	@# twice) — pin it explicitly to the fresh deployment. The project
	@# is CLI-only on purpose: no git link (a repo-root push once
	@# built an EMPTY site that shadowed the real one for an hour).
	cd site && DEPLOY=$$(vercel deploy --prod --yes 2>&1); \
	  echo "$$DEPLOY" | tail -2; \
	  URL=$$(echo "$$DEPLOY" | awk '/Production/ && /jahozs-projects/ {print $$2}' | head -1); \
	  vercel alias set "$$URL" kenos-site.vercel.app; \
	  sleep 3; \
	  curl -fsS -o /dev/null "https://kenos-site.vercel.app/?v=$$(date +%s)" \
	    && echo "landing verified: 200" \
	    || (echo "LANDING BROKEN — check vercel alias" && exit 1)

db-start: ## Start the local Supabase stack (ports 56321-56324)
	supabase start

db-reset: ## Recreate the local database from the migrations
	supabase db reset

db-test: ## pgTAP suite: 149 SQL invariants (RPC + RLS)
	supabase test db

db-push: ## Push unapplied migrations to the linked cloud project
	supabase db push

db-seed-load: ## Seed a 30-day load ramp into the local ether (READABLE sealed payloads, ~12k rows)
	dart run tool/gen_load_payloads.dart > /tmp/kenos_payloads.csv
	docker exec -i supabase_db_kenos psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
		-c "drop table if exists public.kenos_load_payloads" \
		-c "create unlogged table public.kenos_load_payloads (seq serial primary key, text_value text, key_b64 text, payload_b64 text)"
	{ printf '\\copy public.kenos_load_payloads (text_value, key_b64, payload_b64) FROM STDIN WITH (FORMAT csv)\n'; cat /tmp/kenos_payloads.csv; printf '\\.\n'; } \
		| docker exec -i supabase_db_kenos psql -U postgres -d postgres -v ON_ERROR_STOP=1
	docker exec -i supabase_db_kenos psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/snippets/load_seed.sql

db-verify-load: ## End-to-end proof: consume a seeded echo + corpse, open on-device
	dart run tool/verify_load_seed.dart

db-load-report: ## Visualize the ramp: daily volumes, sector culling, case coverage
	docker exec -i supabase_db_kenos psql -U postgres -d postgres < supabase/snippets/load_report.sql

db-garden: ## Plant open constellation rings up to target (local gardener)
	docker exec -i supabase_db_kenos psql -U postgres -d postgres \
		-c "select public.kenos_garden_seed();"

db-sow-vestiges: ## AI-sow vestige shards (2-pass verify; review staging, then --emit)
	dart run tool/gen_vestiges.dart $(SOW_ARGS)

db-curate: ## Curate poetry artifacts + vestiges (local, idempotent)
	docker exec -i supabase_db_kenos psql -U postgres -d postgres \
		-v ON_ERROR_STOP=1 < supabase/snippets/curate_constellations.sql
	docker exec -i supabase_db_kenos psql -U postgres -d postgres \
		-v ON_ERROR_STOP=1 < supabase/snippets/curate_vestiges.sql

db-wipe-load: ## Clean reset: remove every seeded row (real data + KEK untouched)
	docker exec -i supabase_db_kenos psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/snippets/load_wipe.sql

prod-reset: ## LAUNCH RESET (cloud): wipe test wake, keep curated+vestiges, replant garden
	bash scripts/prod_admin.sh file supabase/snippets/prod_reset.sql

prod-sow: ## Sow the generated sky (cloud): 360 real sealed echoes, no dead stars
	dart run tool/gen_load_payloads.dart 360 > /tmp/kenos_sky_payloads.csv
	bash scripts/prod_admin.sh stage /tmp/kenos_sky_payloads.csv
	bash scripts/prod_admin.sh file supabase/snippets/prod_sow.sql

e2e: ## Full bottle-in-the-sea loop over the real local PostgREST
	bash scripts/e2e_local.sh

gen-icons: ## Regenerate Web/Android/iOS icons (stdlib only)
	python3 tool/gen_icons.py

gen-audio: ## Regenerate the synthesized audio assets (stdlib only)
	python3 tool/gen_audio.py
