-- 0008 — take EXECUTE on every function away from PUBLIC.
--
-- ## The defect this fixes, and how it was found
--
-- 0001 ran `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS
-- FROM PUBLIC` precisely so that 0006's functions would not be world-executable.
-- **It did not take.** Read back from the live database after applying:
--
--   complete_chunk -> {=X/vump_admin,vump_admin=X/vump_admin,vump_chunks_verify=X/vump_admin}
--                      ^^^^^^^^^^^^^ the empty grantee is PUBLIC
--   SELECT * FROM pg_default_acl WHERE defaclobjtype='f'  ->  no rows
--
-- So the default-privileges statement recorded nothing, and PostgreSQL's
-- built-in default — EXECUTE to PUBLIC on every new function — stood.
--
-- The consequence was not cosmetic. `complete_chunk()` is the BR-21 gate, and
-- 0007 claims "the only role that can complete a chunk is the one granted
-- EXECUTE". With PUBLIC holding EXECUTE that sentence was false: every
-- per-function role could call it, so `vump_metadata` or `vump_projects` could
-- transition a chunk to 'complete'. The function's own checks still applied, so
-- it was a privilege leak rather than a data-integrity hole — but the boundary
-- 0007 describes did not exist.
--
-- Found by verifying the applied schema against V8.4 §1 by reading the database
-- rather than by re-reading the migration, which is the only way this class of
-- defect surfaces: the SQL was accepted, the statement succeeded, and the
-- privilege was still there.
--
-- ## Why this is a new migration and not an edit to 0001
--
-- 0001 and 0006 are applied. The runner records a checksum per migration and
-- refuses to run when a file has changed, because an edited migration means the
-- database and the repository describe different schemas. History is appended
-- to, not rewritten — the same rule ADR-019 applies to commits.
--
-- ## Explicit revokes, not another default-privileges statement
--
-- The `ALTER DEFAULT PRIVILEGES` line is repeated below for functions created
-- *after* this migration, but it is no longer load-bearing: each existing
-- function is revoked by name. A privilege that must not exist is worth stating
-- directly rather than inferring from a default.

REVOKE ALL ON FUNCTION complete_chunk(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION chunk_metadata_immutable() FROM PUBLIC;

REVOKE ALL ON FUNCTION chunks_completion_guard() FROM PUBLIC;

-- Re-stated so this file is self-contained: the one role that may complete a
-- chunk. Already granted by 0007; granting twice is a no-op.
GRANT EXECUTE ON FUNCTION complete_chunk(uuid) TO vump_chunks_verify;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
