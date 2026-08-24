-- 0015 — TEMPORARY: the shared task is the walkthrough, not a pagination fixture.
--
-- ## What this corrects
--
-- Migration 0014 flagged `f4a31a7f-9d7b-4671-a53b-661327328db2`, the task this
-- project had recorded against throughout Missions 7 and 8. It works, and it
-- reads badly: its title is **"F2 pagination seed 68"** and its instructions
-- say *"Seeded to exceed the 200-row page limit for F2 cursor verification."*
--
-- A Collector opening the app sees that as their one assignment. It looks like
-- a bug, or like seed data nobody cleaned up, and the whole point of 0014 was
-- to give a new tester something to do.
--
-- The right row was already there. Checkpoint Project holds **202 tasks and
-- 201 of them are pagination fixtures**; the one that is not is
-- `208f416c-a707-4df4-a25c-5b45707803b0`, **"Checkpoint walkthrough"**, whose
-- instruction is *"Record a short walkthrough"* — an actual assignment. It is
-- also the oldest task in the project, created with the Mission 7.4 checkpoint
-- seed, so it is the one that was always meant to be demonstrable.
--
-- ## Why a migration rather than an UPDATE against dev
--
-- 0014 is applied and its checksum is recorded, so editing it is a hard error
-- under ADR-046 — the only correct response is to append. A direct `UPDATE`
-- would have fixed dev and left the wrong id baked into the migration every
-- other environment will run, so the environments would disagree about which
-- task is shared. Forward-only means the correction is a file, not a fix-up.
--
-- ## THIS IS STILL TEMPORARY
--
-- Part of the same mechanism 0014 introduced, superseded by the same open
-- items 89 and 92, and listed in the same place — open item 148 carries the
-- deletion list and now names this migration alongside 0014.
--
-- ## Idempotent by shape, and a no-op where neither row exists
--
-- The first statement clears the flag wherever it is set rather than naming
-- 0014's id, so it cannot be defeated by the flag having been moved by hand in
-- between. The second is scoped by project as well as by id, so a uuid
-- collision cannot flag a row in some other project.
--
-- In an environment holding neither row — staging and prod today — both
-- statements match nothing and the migration is a recorded no-op. That is the
-- point of doing it this way: whenever those environments run the ladder, they
-- arrive at the same answer dev has.
UPDATE tasks
   SET shared_with_org = false
 WHERE shared_with_org = true;

UPDATE tasks
   SET shared_with_org = true
 WHERE id         = '208f416c-a707-4df4-a25c-5b45707803b0'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;
