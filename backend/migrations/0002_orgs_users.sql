-- 0002 — orgs and users.
--
-- `orgs` is Volume 4 Chapter 4.3's ninth table. Its ERD opens `orgs ──< users`
-- and its relationship table carries `orgs → users` and `orgs → projects`, and
-- Chapter 4.4's data dictionary never defines it — while defining two NOT NULL
-- foreign keys that point at it. Its three columns are the Mission 6.3.1
-- decision, recorded as amendment A-154.
--
-- `gen_random_uuid()` is built into PostgreSQL 16 — no pgcrypto, no uuid-ossp.
-- Verified against the live cluster rather than assumed.

CREATE TABLE orgs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE orgs IS
  'Tenant boundary. BR-20 scopes every Admin query by org. Ninth table of Ch 4.3, defined in Mission 6.3 (A-154).';

CREATE TABLE users (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid        NOT NULL REFERENCES orgs (id),
  email        text        NOT NULL UNIQUE,
  firebase_uid text        NOT NULL UNIQUE,
  role         text        NOT NULL,
  display_name text,
  created_at   timestamptz NOT NULL DEFAULT now(),

  -- Chapter 4.4: "'admin' or 'collector' (Chapter 1.6); CHECK constraint
  -- restricts values." Chapter 4.4 §9 defers the exact SQL to implementation.
  CONSTRAINT users_role_check CHECK (role IN ('admin', 'collector'))
);

-- Chapter 4.7 §1 step 4 looks the caller up by firebase_uid on every request.
-- The UNIQUE constraint above already indexes it; this comment records that the
-- lookup path is covered rather than adding a redundant index.
COMMENT ON COLUMN users.firebase_uid IS
  'Join key to Firebase Authentication (Ch 4.7). UNIQUE, so the Ch 4.7 §1 step 4 lookup is indexed.';

CREATE INDEX users_org_id_idx ON users (org_id);
