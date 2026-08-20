-- 0012 — Invite codes move from Firestore to Postgres, and the role that
-- redeems them.
--
-- ADR-036 put invite-code redemption in a Firebase Cloud Function and said, in
-- terms, that it was temporary: "When the real backend exists, redeemInviteCode
-- becomes a /v1/... route beside the others, this function is deleted, and this
-- ADR is superseded." This migration is the storage half of that port.
--
-- ## What carries over, and what the schema absorbs
--
-- The Firestore document has three fields — orgId, expiresAt, remainingUses —
-- and the function validates all three at read time because Firestore cannot.
-- Two of those validations disappear into the schema here:
--
--   * "Invite code document has no orgId"      → org_id uuid NOT NULL + FK
--   * "…has no usable expiresAt"               → expires_at timestamptz NOT NULL
--
-- Both were reported as `misconfigured()` — an internal error, because a
-- malformed code document is a defect rather than a caller mistake. In Postgres
-- the malformed state is unrepresentable, so the branch is not ported; it is
-- retired. What remains for the route to check is expiry and exhaustion, which
-- are conditions rather than defects.
--
-- ## Existing Firestore codes are NOT migrated — Mission 7.6 Phase 1, ruled
--
-- ADR-046 makes migrations forward-only and this one carries no data. Two
-- reasons rather than one. Mixing a data copy into a schema change gives the
-- migration two failure modes and one checksum. And A-056 made the invite code
-- optional: "Self-signup needs no invite code. Without one an account joins a
-- single default organisation as a Collector." A code that stops working is
-- therefore not a lockout — it is a code that stops working, and the person
-- signs up without one.
--
-- If codes are needed again they are created through an admin write route,
-- which does not exist yet. See the grant note at the bottom.

-- ===========================================================================
-- The table
-- ===========================================================================
-- `code` is the primary key because Firestore already treats it as the
-- identity — `collection(COLLECTION).doc(code)` — so the value is the row's
-- name in both stores. A surrogate id would add a second identity for a thing
-- that already has one, and every lookup is by code.
CREATE TABLE org_invite_codes (
  code           text        PRIMARY KEY,
  org_id         uuid        NOT NULL REFERENCES orgs (id),
  expires_at     timestamptz NOT NULL,

  -- NULL means unlimited. This is the one null in the table that carries
  -- meaning rather than absence, and it is load-bearing: the Cloud Function
  -- says so directly — "Null means unlimited, matching Mission 2.1's
  -- OrgInviteCode" — and Mission 2.1's entity models it the same way. A
  -- DEFAULT of 0 or 1 here would silently redefine every unlimited code.
  remaining_uses integer,

  -- Not in the Firestore shape. Added deliberately: every other table in this
  -- schema carries one, and an invite code is a credential-like object whose
  -- creation time is worth having when one is later found to have been
  -- misused. Approved as an addition rather than a transcription.
  created_at     timestamptz NOT NULL DEFAULT now(),

  -- The function refuses a code with `remainingUses <= 0` and reports it as
  -- invalid rather than as its own condition, "because telling a caller a code
  -- exists but is used up confirms the code exists". That refusal stays in the
  -- route; this constraint is the narrower statement that the counter must
  -- never go negative, which no correct decrement can produce and which a
  -- racing one might.
  CONSTRAINT org_invite_codes_uses_non_negative
    CHECK (remaining_uses IS NULL OR remaining_uses >= 0)
);

COMMENT ON TABLE org_invite_codes IS
  'Org invite codes, ported from the Firestore collection ADR-036 created. One row per code; the code is the key (Mission 7.6).';

COMMENT ON COLUMN org_invite_codes.remaining_uses IS
  'NULL means unlimited (Mission 2.1 OrgInviteCode, ADR-036). A number is decremented transactionally on redemption and must never go negative.';

COMMENT ON COLUMN org_invite_codes.expires_at IS
  'Compared against the server clock only. ADR-036: "A device clock is attacker controlled, so an expiry checked on the caller''s time is no expiry."';

-- ===========================================================================
-- The redeem role
-- ===========================================================================
-- NOLOGIN for the reason 0007 records: migrations are committed to git, and a
-- `CREATE ROLE … LOGIN PASSWORD` in one would be a credential in source
-- control, which ADR-016 forbids permanently. `npm run db:bootstrap` sets the
-- password and writes it to this function's Secrets Manager secret.
CREATE ROLE vump_redeem NOLOGIN;

GRANT USAGE ON SCHEMA public TO vump_redeem;

-- Column-level, following 0011's precedent rather than granting the table.
-- 0011 withheld row-level UPDATE from chunks-upload and granted one column, on
-- the reasoning that a role should hold exactly the mutation its job needs.
--
-- This role does two things: spend one use of a code, and create the account
-- that use admits. It cannot create a code, cannot delete one, cannot extend an
-- expiry, and cannot change a code's organisation — so a compromised redeem
-- path cannot mint itself an invitation to a tenant it was not given.
GRANT SELECT (code, org_id, expires_at, remaining_uses)
  ON org_invite_codes TO vump_redeem;

GRANT UPDATE (remaining_uses)
  ON org_invite_codes TO vump_redeem;

-- The account the code admits. Same four columns auth-verify inserts on first
-- login, and for the same reason A-150 gives: inserting a row keyed by a
-- firebase_uid the server itself just created does not serve the threat V8.4
-- §1 names, which is a verification path "leveraged into a data-write path".
--
-- No UPDATE and no DELETE. The role can bring an account into existence and
-- can never alter one afterwards — which is what makes the hard-locked
-- Collector role structural rather than conventional: this grant cannot
-- promote anybody, and `users_role_check` bounds the value it may insert.
GRANT INSERT (org_id, email, firebase_uid, role)
  ON users TO vump_redeem;

-- ===========================================================================
-- What is deliberately NOT granted
-- ===========================================================================
-- No role may INSERT, UPDATE or DELETE an invite code. That is not an
-- oversight — it is the Firestore security rules' enforcement half, which
-- ADR-036 is explicit about: "security rules — not the UI — enforce who may
-- write them."
--
-- There is no admin write route for invite codes today. Granting one now would
-- be a permission that presupposes a design, which is the pattern Mission 6.5
-- refused when it removed auth-verify's Firebase secret grant: "a permission
-- that presupposes a key is a quiet vote for the key half of the answer
-- ADR-036 deferred." Whatever builds the admin write route adds the grant it
-- actually needs, and argues for it there.
--
-- Until then codes are created by a human with faisal-admin, the same way the
-- Mission 7.4 checkpoint fixture was, and A-210 records why that provenance is
-- worth writing down when it happens.
