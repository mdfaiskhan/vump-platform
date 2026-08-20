-- 0013 — vump_redeem loses INSERT on users, which it never needed.
--
-- ## What this corrects
--
-- Migration 0012 granted:
--
--     GRANT INSERT (org_id, email, firebase_uid, role) ON users TO vump_redeem;
--
-- on the reading that the redeem route would create the account's database row
-- the way `redeemInviteCode` created its Firestore state. Tracing Phase 3
-- against the code showed that reading is wrong.
--
-- `provisionCaller` in `backend/packages/shared/src/caller.ts` **already**
-- inserts the row, on first login, from the token's own claims:
--
--     INSERT INTO users (org_id, email, firebase_uid, role)
--     VALUES (:orgId::uuid, :email, :uid, :role)
--     ON CONFLICT (firebase_uid) DO NOTHING
--
-- That is Chapter 4.7 §1 step 4, it runs on `POST /v1/auth/verify`, and the
-- redeem flow reaches it unavoidably: the client signs in with the credentials
-- it just created, and the first authenticated call provisions the row.
--
-- The claims carry everything the insert needs. `resolveOrgId` passes a real
-- uuid straight through, so an invite code's organisation reaches
-- `users.org_id` with no change anywhere — which is the fact that makes the
-- grant redundant rather than merely duplicated.
--
-- ## Why removing it matters more than leaving it
--
-- The grant is not dangerous today; nothing calls it. That is exactly the
-- problem. An unused privilege is invisible until something reaches for it,
-- and the next author to need a users row from redeem will find the grant
-- already there and use it — creating a second provisioning path, with its own
-- copy of the org resolution and role literal, that nobody decided to build.
--
-- Volume 8 Chapter 8.4 §1's least privilege is a statement about what a
-- principal CAN do, not about what it currently does. `vump_redeem` should be
-- able to read an invite code, spend a use, and nothing else.
--
-- ## Forward-only
--
-- ADR-046 makes migrations forward-only with checksums, so 0012 is not edited.
-- Its grant happened and this records that it was withdrawn, which is the
-- history worth keeping: the column list in 0012 explains what was intended,
-- and this explains why it turned out to be unnecessary.

REVOKE INSERT (org_id, email, firebase_uid, role)
  ON users FROM vump_redeem;

-- Belt and braces. The statement above names the exact column list 0012
-- granted; this catches a table-level INSERT if one was ever granted by
-- another path, and is a no-op otherwise.
REVOKE INSERT ON users FROM vump_redeem;

COMMENT ON TABLE org_invite_codes IS
  'Invite codes, ported from Firestore by Mission 7.6 (ADR-036 retirement). vump_redeem may SELECT a code and decrement remaining_uses; it may not create, alter or delete one, and since 0013 it may not write to users either — provisionCaller does that on first login.';
