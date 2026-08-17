-- 0001 — Schema hardening, before any table exists.
--
-- PostgreSQL 16 no longer grants CREATE on `public` to PUBLIC, but it still
-- grants USAGE, and `ALTER DEFAULT PRIVILEGES` has not been touched. Without
-- this migration every table created later is readable by every role by
-- default, and the per-function GRANTs in 0007 become decoration.
--
-- Run first, deliberately: revoking defaults after tables exist leaves whatever
-- was granted in the meantime.

REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO PUBLIC;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;

-- Functions are the exception worth calling out: PUBLIC holds EXECUTE on new
-- functions by default, which would hand every role the BR-21 completion
-- procedure that 0006 creates. Revoked here so 0007 can grant it to exactly
-- one function.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;
