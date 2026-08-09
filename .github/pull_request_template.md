## Summary

<!-- What changes, and why. One or two sentences. The diff shows what; explain why. -->

## Type

<!-- Tick one. If two apply, this is probably two pull requests. -->

- [ ] `feat` — new capability
- [ ] `fix` — defect correction
- [ ] `refactor` — structural change, no behaviour change
- [ ] `docs` — documentation or ADR
- [ ] `test` — tests only
- [ ] `chore` / `ci` — tooling, dependencies, pipeline
- [ ] `perf` — performance

## Related

<!-- Closes #123 / Refs #456 — or "none". -->

## Architecture

<!-- Governance is not optional. See docs/architecture/README.md. -->

- [ ] I read the accepted ADRs that apply to this change.
- [ ] This change contradicts no accepted ADR.
- [ ] Layer boundaries hold — no package escapes the layer that owns it
      (`dio` → `core/network`, `isar` → `core/database`,
      `flutter_secure_storage` → `core/storage`,
      `firebase_core` → `core/firebase`).

**ADRs this change implements or is constrained by:**

<!-- e.g. "Implements ADR-009" / "Constrained by ADR-007" / "none" -->

- [ ] This change introduces or alters an architectural decision, and a new
      ADR is included in this pull request.

<!-- If you ticked the box above and there is no ADR here, stop and write it.
     An architectural decision that is not recorded does not exist. -->

## Verification

- [ ] `flutter analyze` — no issues
- [ ] `flutter test` — all pass
- [ ] `dart format` — clean
- [ ] Tests added or updated for the behaviour changed
- [ ] Ran on a device or emulator, where the change is user-visible

<!-- If any box is unticked, say why below. An honest gap is fine; an
     unexplained one is not. -->

## Secrets

- [ ] No API key, token, credential, service account or signing key appears in
      this diff, including in test fixtures and log output.

<!-- ADR-007. A committed credential is disclosed permanently — deleting it
     later does not remove it from history. -->

## Notes for the reviewer

<!-- Anything that would otherwise cost the reviewer time: a decision you were
     unsure about, a shortcut taken deliberately, a follow-up you have left. -->
