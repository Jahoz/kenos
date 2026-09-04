-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — create the Guardian (V3.16 Observatory operator)
--
-- The ONE account allowed to read admin_fetch_metrics. Run ONCE per
-- environment (local + prod), by the project owner only.
--
-- Step 1 — create the user (Dashboard → Authentication → Add user):
--            email  : <gardien@example.com>
--            password: <a long unique secret>
--          (Do NOT tick "auto-confirm"? — DO tick it: the guardian
--          signs in with the password immediately.)
--
-- Step 2 — promote (this snippet, idempotent). The claim lives in
--          raw_app_meta_data — operator-set, NOT user-editable.
--          raw_user_meta_data would be forgeable and is never read
--          by the gate (pgTAP pins this).
--
-- Step 3 — sign in from the app's hidden door (long-press L'Aube on
--          the map). The fresh JWT carries the claim; nothing is
--          stored on the device between sessions.
-- ═══════════════════════════════════════════════════════════════════════

-- Set the guardian's email, then run:
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                          || '{"role":"admin"}'::jsonb
 where email = 'gardien@example.com';

-- Verify (expect exactly one row, role admin):
--   select email, raw_app_meta_data ->> 'role' as role
--     from auth.users
--    where raw_app_meta_data ->> 'role' = 'admin';

-- Demote (revoke the observatory) — the claim dies, the dashboard
-- closes at the next sign-in:
--   update auth.users
--      set raw_app_meta_data = raw_app_meta_data - 'role'
--    where email = 'gardien@example.com';
