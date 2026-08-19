/**
 * Volume 4 Chapter 4.5 §2's canonical metadata document, as a schema.
 *
 * ## Why a library, and why this one — ADR-045
 *
 * `request.ts` hand-rolls validation for Batch 1's bodies and says in its own
 * header that it stops being the right answer here: *"Revisit when the first
 * genuinely nested body arrives. That is Chapter 4.5 §2's metadata document…
 * which has six groups and twenty-one fields."*
 *
 * ADR-045 makes a runtime dependency a decision rather than a convenience — it
 * bundles into the function and is audited on every CI run — so the choice was
 * **measured** rather than defaulted to whatever is popular:
 *
 *   | library  | metadata bundle | delta   |
 *   |----------|-----------------|---------|
 *   | (none)   | 1600 KiB        | —       |
 *   | zod      | 2131 KiB        | +531 KiB|
 *   | valibot  | 1609 KiB        | **+9 KiB** |
 *
 * Both measured with a trivial schema referenced, so esbuild's tree-shaking was
 * already applied. zod's runtime is one object graph that resists shaking;
 * valibot is a function per validator and shakes away almost entirely. A 59×
 * difference on a cold-start path, and the popular option is the one that fails
 * this project's own test.
 *
 * ## What the schema does not do
 *
 * It checks **shape**, not truth. Every field in `identity` and `timing` that
 * names something the server already knows is re-checked against the database
 * in `index.ts` and refused on mismatch — Chapter 4.8 §1's *"No authorization
 * decision is ever trusted from the mobile client"*, applied to identity as
 * well as to scope.
 */
import * as v from 'valibot';

const uuid = v.pipe(v.string(), v.uuid());
const iso = v.pipe(v.string(), v.isoTimestamp());

/**
 * FR-META-01–07's groups, in Chapter 4.5 §2's order.
 *
 * Nullability follows Chapter 4.4 §7 exactly: the `capture_conditions` fields
 * are *"nullable where permission/condition dependent"* — a Collector may
 * decline location permission — and everything else is NOT NULL because the
 * device always knows it.
 */
export const MetadataDocument = v.object({
  chunk_id: uuid,

  identity: v.object({
    session_id: uuid,
    project_id: uuid,
    task_id: uuid,
    collector_id: uuid,
    device_id: v.pipe(v.string(), v.minLength(1), v.maxLength(200)),
  }),

  timing: v.object({
    sequence_index: v.pipe(v.number(), v.integer(), v.minValue(0)),
    started_at: iso,
    ended_at: iso,
    // Chapter 4.5 §2 carries it; Chapter 4.4 §7 has no column for it, because
    // it is `ended_at - started_at`. Accepted and not stored, rather than
    // rejected — refusing a field the canonical shape includes would make the
    // wire format disagree with the chapter that defines it.
    duration_seconds: v.pipe(v.number(), v.minValue(0)),
  }),

  capture: v.object({
    resolution: v.pipe(v.string(), v.minLength(1), v.maxLength(50)),
    frame_rate: v.pipe(v.number(), v.integer(), v.minValue(1)),
    bitrate_kbps: v.pipe(v.number(), v.integer(), v.minValue(1)),
    codec: v.pipe(v.string(), v.minLength(1), v.maxLength(50)),
    zoom_factor: v.pipe(v.number(), v.minValue(0)),
    camera: v.pipe(v.string(), v.minLength(1), v.maxLength(50)),
  }),

  device_context: v.object({
    device_model: v.pipe(v.string(), v.minLength(1), v.maxLength(200)),
    os_version: v.pipe(v.string(), v.minLength(1), v.maxLength(100)),
    app_version: v.pipe(v.string(), v.minLength(1), v.maxLength(100)),
  }),

  capture_conditions: v.object({
    // Absence has THREE spellings on this field, and all three are accepted.
    //
    // The object may be null or absent; its members may independently be null.
    // That is not permissiveness for its own sake — `chunk_metadata.gps_lat`
    // and `gps_lng` are two independently nullable columns, so a schema
    // requiring both-or-neither is NARROWER than the table it writes to, and
    // could reject a half-fix the storage model permits.
    //
    // The client sends `{lat: null, lng: null}` rather than `gps: null`, and
    // says why: omitting the object entirely "would make 'no fix' and 'field
    // not implemented' the same wire value". Chapter 4.5 §2 nests the
    // coordinates and never says what a missing fix looks like, so both
    // readings were defensible and the two halves picked different ones. The
    // first real device request is what found it. A-211.
    gps: v.nullish(
      v.object({
        lat: v.nullish(v.pipe(v.number(), v.minValue(-90), v.maxValue(90))),
        lng: v.nullish(v.pipe(v.number(), v.minValue(-180), v.maxValue(180))),
      }),
    ),
    // `chunk_metadata_battery_range` enforces 0–100 in the schema too. Checked
    // here as well so a bad value is REQUEST_INVALID rather than a constraint
    // violation surfacing as INTERNAL_ERROR.
    battery_pct: v.nullish(v.pipe(v.number(), v.integer(), v.minValue(0), v.maxValue(100))),
    network_type: v.nullish(v.pipe(v.string(), v.maxLength(50))),
  }),

  integrity: v.object({
    file_size_bytes: v.pipe(v.number(), v.integer(), v.minValue(1)),
    checksum_sha256: v.pipe(v.string(), v.regex(/^[0-9a-f]{64}$/i)),
  }),

  // FR-META-07, BR-22's one mutable column. Optional: a Collector need not
  // author anything, and Chapter 4.4 §7 makes `notes_tags` nullable.
  collector_authored: v.nullish(
    v.object({
      notes: v.nullish(v.pipe(v.string(), v.maxLength(5000))),
      tags: v.nullish(v.array(v.pipe(v.string(), v.maxLength(100)))),
    }),
  ),
});

/** The validated document. */
export type MetadataDocument = v.InferOutput<typeof MetadataDocument>;
