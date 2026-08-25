-- 0016 — Checkpoint Project becomes Tailoring Workshop, with real task names.
--
-- ## Why this exists
--
-- The project and its tasks were seeded for Mission 7.4's device checkpoint and
-- for F2's cursor-pagination verification. Both are closed. What is left is a
-- project called "Checkpoint Project" whose one shared task reads "Checkpoint
-- walkthrough" and whose other 201 read "F2 pagination seed N" — which a new
-- tester reasonably reads as a broken app rather than as an assignment.
--
-- Migration 0015 already fixed exactly this failure one row over, moving
-- `shared_with_org` off a task titled "F2 pagination seed 68". This finishes the
-- job for the names themselves.
--
-- ## RENAMES ONLY. NOTHING IS DELETED, AND NOTHING CAN BE.
--
-- The Mission 8.2A trace counted what could be removed and the answer was none:
--
--     fixtures_total         201
--     blocked_by_session       9   -- 25 sessions, 28 chunks, 25 of them 'complete'
--     blocked_by_assignment  201
--     deletable                0
--
-- Every task in this project carries an active `task_assignments` row — an
-- artefact of BR-19, since the F2 seed had to assign each task for a Collector
-- to see it at all. That FK is declared with no ON DELETE clause (0003:31), so
-- it refuses every delete, and FR-ADM-04 keeps assignments "for audit rather
-- than hard-deleted", so clearing them to get around it would break the rule
-- that put them there. Nine fixtures additionally hold sessions whose chunks are
-- 'complete', meaning real objects in S3 that a delete would orphan.
--
-- A rename touches no foreign key at all. Volume 5 Chapter 5.14 §4 guarantees it
-- is safe: keys are ID-based "since display names can change (an Admin renaming
-- a Project, FR-ADM-02) and must never invalidate or orphan already-uploaded
-- footage." No S3 key moves. No session, chunk, metadata row or assignment is
-- touched.
--
-- ## Why these particular seven fixtures
--
-- The seven were chosen as the lowest-id fixtures that hold **no sessions**, so
-- that no existing recording is silently re-labelled as tailoring work it is not.
-- The ordering (`created_at, id`) is deterministic, so the choice is
-- reproducible rather than arbitrary.
--
-- The eighth renamed row is the walkthrough itself. It has to be included: it is
-- the one task carrying `shared_with_org` (migration 0015), so it is the only
-- task a newly-invited Collector can see, and leaving it named "Checkpoint
-- walkthrough" inside a project called "Tailoring Workshop" would preserve the
-- exact confusion this migration removes.
--
-- ## All eight become visible to every Collector in the org
--
-- Ruled at Mission 8.2A Part 5. Migration 0015 left `shared_with_org` on exactly
-- one row, so a newly-invited Collector saw exactly one task. Renaming eight and
-- sharing one would have produced a workshop with a single visible job in it.
--
-- This widens open item 148's mechanism from one task to eight. **It does not
-- change what the mechanism is, what it relaxes, or how long it lives.** Same
-- column, same `OR t.shared_with_org` in the same three queries, same supersession
-- by open items 89 and 92, same deletion list. Only the number of flagged rows
-- moves, and item 148 carries a dated amendment saying so.
--
-- **BR-20 is untouched, which is the property worth restating whenever this
-- mechanism widens.** All three queries keep `p.org_id = :orgId`, so eight
-- flagged tasks in this organisation remain invisible to every other. Widening
-- the count does not widen the blast radius; it stays inside one org either way.
--
-- ## The 193 fixtures are deliberately left alone
--
-- Ruled at Mission 8.2A Part 4. They stay visible to whoever holds their
-- assignments, still named "F2 pagination seed N". Hiding them would need an
-- `archived_at` column on `tasks` — which does not exist, only `projects` has
-- one — plus a filter in the same three queries `shared_with_org` touched. That
-- is a schema change, and it was judged not worth it here.
--
-- ## Environment reality
--
-- Every statement is scoped by primary key and by project. In an environment
-- that does not hold these rows — staging and prod today — this migration is a
-- recorded no-op, which is the same shape 0014 and 0015 use for seeded data.

-- ---------------------------------------------------------------------------
-- The project
-- ---------------------------------------------------------------------------
UPDATE projects
   SET name        = 'Tailoring Workshop',
       description = 'Garment workshop walkthroughs — measurement, cutting, stitching, finishing and handover.'
 WHERE id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

-- ---------------------------------------------------------------------------
-- The walkthrough — already shared by 0015, renamed here
-- ---------------------------------------------------------------------------
UPDATE tasks
   SET title        = 'Taking customer measurements',
       instructions = 'Record a full measurement session, from greeting the customer to writing the measurements down. Keep both hands and the tape in frame.'
 WHERE id         = '208f416c-a707-4df4-a25c-5b45707803b0'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

-- ---------------------------------------------------------------------------
-- Seven fixtures with no sessions
-- ---------------------------------------------------------------------------
UPDATE tasks
   SET title        = 'Fabric cutting — trousers',
       instructions = 'Record laying out the fabric, marking it and cutting a single trouser panel. Keep the marking chalk and the shears in frame.'
 WHERE id         = '002eca68-433a-49ec-9fe3-6e6c4fa5a77b'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Machine stitching — side seam',
       instructions = 'Record one continuous side seam, from setting up the machine to the closing backstitch.'
 WHERE id         = '01453c85-a147-41cb-b1da-71be23735f01'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Buttonhole and button attachment',
       instructions = 'Record marking, cutting and finishing one buttonhole, then attaching its button.'
 WHERE id         = '019e5924-3415-4e87-ad55-081165c75d09'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Hemming and finishing',
       instructions = 'Record the hem from pinning through stitching to the final press.'
 WHERE id         = '035999fe-adf4-4d49-a718-31d242724c49'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Fitting session with customer',
       instructions = 'Record a trial fitting, including pinning any adjustments and noting what needs changing.'
 WHERE id         = '041209c7-47ca-4f61-8707-d36b06c4bc1c'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Pressing and final inspection',
       instructions = 'Record the final press and the quality check before the garment is handed over.'
 WHERE id         = '08577471-7aa6-48ff-af23-2afde6d62583'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

UPDATE tasks
   SET title        = 'Handover and payment',
       instructions = 'Record handing the finished garment to the customer and closing the order.'
 WHERE id         = '0899811c-ae82-4933-bded-60e472cd1ff2'::uuid
   AND project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid;

-- ---------------------------------------------------------------------------
-- Share all eight with the org
--
-- One statement rather than eight, and scoped by project as well as by id so a
-- uuid collision cannot flag a row in another project. The walkthrough is
-- included even though 0015 already set it: stating the intended end state is
-- what makes this migration idempotent in shape, and re-setting a true value
-- costs nothing.
--
-- Nothing here clears the flag elsewhere. 0015 already reduced the set to one
-- row, and after this migration the set is exactly these eight.
-- ---------------------------------------------------------------------------
UPDATE tasks
   SET shared_with_org = true
 WHERE project_id = '4889ca14-11d6-4142-8ae3-c5e96be62f7f'::uuid
   AND id IN (
     '208f416c-a707-4df4-a25c-5b45707803b0'::uuid,
     '002eca68-433a-49ec-9fe3-6e6c4fa5a77b'::uuid,
     '01453c85-a147-41cb-b1da-71be23735f01'::uuid,
     '019e5924-3415-4e87-ad55-081165c75d09'::uuid,
     '035999fe-adf4-4d49-a718-31d242724c49'::uuid,
     '041209c7-47ca-4f61-8707-d36b06c4bc1c'::uuid,
     '08577471-7aa6-48ff-af23-2afde6d62583'::uuid,
     '0899811c-ae82-4933-bded-60e472cd1ff2'::uuid
   );
