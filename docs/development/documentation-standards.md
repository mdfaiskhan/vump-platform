# Documentation Standards

The canonical documentation standard for the Vump Technologies repository.

Governed by **ADR-024**. Where this document and the ADR disagree, the ADR governs.

Every rule below was derived from an audit of every tracked markdown file, not chosen from preference. Where the repository was already consistent, the existing practice is the rule. Where it was not, the deviation is recorded in §30 rather than resolved by a rewrite.

Counts in this document are re-verified when it is edited, per §30, **and are measured after staging** — `git ls-files` is blind to untracked files, so a count taken before `git add` omits exactly the documents the current mission just wrote (ADR-032). They were last verified at **57 markdown files and 33 ADRs**.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 0 Ch. 0.2 (Project Constitution) §1, §8, §9 | Every decision is written down; documentation governs code; the change-management process |
| Volume 0 Ch. 0.3 (Glossary) | The authoritative meaning of every recurring domain term |
| `CLAUDE.md` | The engineering constitution; architecture governance rules |
| `docs/architecture/README.md` | The ADR lifecycle, the ADR template, ADR filenames |
| ADR-023 · `naming-conventions.md` | Documentation filenames, ADR filenames, markdown heading case, terminology |
| ADR-022 · `folder-structure.md` | Which directory a document belongs in |
| ADR-021 | `missing_code_block_language_in_doc_comment` for Dart doc comments |
| ADR-020 · `commit-conventions.md` | The `docs` commit type and the `docs/adr` scope |
| ADR-019 | Branch names for documentation work |

---

## Purpose and hierarchy

### 1. Purpose of documentation

Documentation exists to answer **"why is it built this way?"** long after everyone who decided has forgotten.

The Project Constitution §1 states the position this repository operates under: *"Every decision is written down. A choice that is not recorded in these documents does not count as decided — it will be re-litigated the next time it comes up."* And: *"Documentation drives code, not the other way around."*

That fixes what documentation is **for**, and therefore what it is **not** for. Documentation does not restate what the code says — the code is authoritative about its own behaviour and never out of date. Documentation records what the code cannot: the constraint that forced a choice, the alternative rejected, the failure that prompted a rule.

**The test for whether a sentence belongs in a document:** could a reader derive it by reading the code? If yes, delete it — it will rot and mislead. If no, it is the only place that information exists.

### 2. Documentation hierarchy

Nine document types exist. Each has one job, one location, and one authority level.

| Type | Location | Authority | Changes when |
|---|---|---|---|
| **Source volumes** | `docs/volumes/*.pdf` | The original specification. Not editable here | Never in this repository — corrections go to the amendment register |
| **Constitution** | `CLAUDE.md` | Binding engineering constitution | Deliberately, as a governance act |
| **ADRs** | `docs/architecture/decisions/` | Binding while `Accepted` | Never — superseded by a new ADR |
| **Amendment register** | `docs/architecture/volume-amendments.md` | Records where an ADR supersedes a volume | Append-only; entries are discharged, never deleted |
| **Process guide** | `docs/architecture/README.md` | Governs how decisions are recorded | Deliberately |
| **Reference / standard** | `docs/architecture/*.md`, `docs/development/*.md` | Specifies what an ADR decides | Freely, to stay accurate |
| **Implementation spec** | `docs/architecture/aws-sdk-integration.md` | Design detail below the ADR level | Freely |
| **Runbook** | `docs/operations/`, `infrastructure/**/README.md` | Operational procedure | Whenever the procedure changes |
| **Orientation README** | `README.md`, `mobile/README.md` | Points elsewhere; owns nothing | Whenever what it points at moves |

**Reading order for a new contributor:** root `README.md` → `CLAUDE.md` → `docs/architecture/README.md` → the accepted ADRs → the reference documents.

### 3. Single source of truth

The precedence chain, in force from the top:

```text
Volume 0 Ch. 0.2 (Constitution)  — overrides later volumes (its own Precedence clause)
        ↓
CLAUDE.md + Accepted ADRs        — override the volumes; the amendment register records where
        ↓
Reference and implementation documents
        ↓
Code
```

Three rules follow, and all three are already stated elsewhere — repeated here only as the joined-up chain:

- **Where code and an accepted ADR disagree, the ADR is correct and the code is a defect** (`CLAUDE.md`, `docs/architecture/README.md`).
- **Where a volume and an accepted ADR disagree, the ADR governs**, and `volume-amendments.md` records the disagreement explicitly rather than leaving it latent.
- **Where two documents state the same rule, one of them is wrong** — because they will diverge, and then the readable one is wrong and the enforced one is undocumented.

**Every non-ADR document MUST state its own precedence** in its opening lines, so a reader knows what to do when it conflicts with something. The established form is one sentence: *"Where this document and the ADR disagree, the ADR governs."* Eighteen of twenty-two documents carry it; the three that should and do not are listed in §30.

**Templates are exempt** (ADR-032). `.github/pull_request_template.md` is a form whose content becomes the body of a pull request, where a precedence sentence would be neither read nor meaningful. The rule applies to documents, not to templates.

**One fact, one home.** A rule lives in exactly one document. Every other mention is a link. This is the rule that makes the rest maintainable, and the one most often broken by good intentions.

### 4. What belongs in a README

A README is a **map, not a manual**. It answers "what is this and where do I go next" and owns no rule.

**Belongs:** what this directory or package is, in one or two sentences; the layout, one line per entry; the commands needed to get started; a table of links to the documents that own the detail; the current status, honestly stated.

**Does not belong:** an architectural decision (that is an ADR); a rule other documents must follow (that is a reference document); a procedure of more than a few commands (that is a runbook); anything already stated in a document it could link to.

**Every directory whose contents are not obvious from their names gets a README.** Today: the repository root, `mobile/`, `infrastructure/aws/`, `infrastructure/aws/cloudfront/`, `docs/architecture/`.

**The test:** if a README's content would be wrong after a change *elsewhere*, it is holding something that belongs elsewhere.

### 5. What belongs in an ADR

Fixed by `docs/architecture/README.md`: one decision, the context that forced it, the alternatives rejected and why, and the consequences accepted. Four required sections — `Context`, `Decision`, `Alternatives Considered`, `Consequences` — plus a `Status`/`Date` block.

Two sections are not in that template but have been used by every ADR since ADR-001 and are now equally expected: **`Related Missions`** and **`Implementation Status`**. All 33 ADRs carry `Related Missions`; 32 carry `Implementation Status` — ADR-002 is the sole exception, recorded in §30.

**Belongs:** the decision, stated plainly in the active voice. The forces that made a decision necessary. Every alternative evaluated, each with the specific reason it was rejected — including the ones that were close calls. What this costs, what it makes harder, and what must now be maintained.

**Does not belong:** a specification (that is a reference document); a tutorial; a task list; API documentation; anything that will change while the decision stands. `docs/architecture/README.md` states this directly: *"An ADR is not a design document, a specification, a tutorial or a task list."*

**The alternatives section is the part that ages best and is written worst.** "Rejected — not suitable" records nothing. The reason must be specific enough that a reader who disagrees can tell whether their objection was already considered.

### 6. What belongs in a reference document

A reference document **specifies what an ADR decides**. The ADR says *what was chosen and why*; the reference says *what to do on Tuesday*.

The pattern is established four times over: ADR-019 with `branching-strategy.md`, ADR-020 with `commit-conventions.md`, ADR-022 with `folder-structure.md`, ADR-023 with `naming-conventions.md`.

**Belongs:** the rule, in enough detail to apply without interpretation; worked examples; the common mistake and how to recognise it; a quick-reference table; a register of known deviations, audited rather than assumed.

**Does not belong:** the decision's justification at length (that is the ADR — summarise and link); historical alternatives; anything that would need rewriting when the decision is superseded rather than when practice changes.

**A reference document is expected to change.** That is the difference from an ADR: an ADR is a historical record and is immutable in spirit; a reference document is a living specification and is wrong the moment it stops matching practice.

### 7. What belongs in an implementation document

An implementation document sits **below the ADR level**: it describes how components interact in enough detail to build them, where the design is too large for an ADR and too specific for a reference.

One exists — `docs/architecture/aws-sdk-integration.md` — and it declares its own status correctly: *"This is a design and integration specification, not an ADR. Where it and an accepted ADR disagree, the ADR governs."* That declaration is the required form.

**Belongs:** sequence and interaction detail; the rule each step exists to satisfy, cited to its ADR or volume; concrete request and response shapes; what is deliberately deferred.

**Does not belong:** a decision that has no ADR. If an implementation document is the only place a choice is recorded, the choice is undocumented — write the ADR.

---

## Markdown conventions

Every rule in this section was measured across every tracked markdown file. Where the corpus was already unanimous, the count is given.

### 8. General markdown

- **GitHub Flavored Markdown.** No HTML except an HTML comment, and those only in `.github/` templates, where they carry instructions that must not appear in the rendered body.
- **One sentence per line is not used.** Paragraphs are single lines and wrap in the reader's viewport. The corpus is unanimous, and it keeps a reworded sentence to a one-line diff rather than a reflowed block.
- **No trailing whitespace.** Zero occurrences across 38 files.
- **Every file ends with a newline.** One file does not — see §30.
- **Bold for emphasis that carries weight**, and sparingly. Italic for quoted source text. `Backticks` for every identifier, filename, path, command, package and literal value — a bare `main.dart` in prose reads as a sentence fragment.

### 9. Heading hierarchy

- **Exactly one `#` per document**, as the title, on line 1. Unanimous across all 38 files except `.github/pull_request_template.md`, which correctly has none — its content becomes the body of a pull request, where an H1 would be someone else's heading.
- **Never skip a level.** Verified: **zero level skips across all 38 files.**
- **`###` is the floor.** No document goes deeper. Verified: maximum depth is H3 everywhere. A section needing H4 is a document that should be split — that is the Constitution's *"One Chapter = One Document"* applied to this repository.
- **Sentence case**, fixed by ADR-023 §9.1, including its two exceptions for ADR template headings and pre-existing documents.
- **Headings are noun phrases, not questions.** One document uses a question form deliberately (`infrastructure/aws/README.md` — "Why these files exist rather than console clicks"); it reads as a statement of subject rather than a query, which is the line.

### 10. Section separators

**`---` separates top-level sections in prose documents. ADRs never use it.**

Verified, and unanimous: **all 33 ADRs contain zero horizontal rules**, while every prose document uses between 3 and 11. The ADR template's headings carry the structure by themselves; a rule between `## Decision` and `## Alternatives Considered` adds a line and no information.

Use one `---` between top-level (`##`) sections of a reference, guide or runbook. Never inside a section, never before the first heading, never two in a row.

### 11. Lists

- **`-` for unordered lists.** Never `*` or `+`. Unanimous.
- **`1.` for ordered lists**, and only where the order is meaningful — a procedure, a precedence chain, a numbered lifecycle. A list of peers is unordered even when it has a natural reading order.
- **Two-space indent for nesting**, and one level of nesting only. A second level is a table or a subsection.
- **A list item is a fragment or a sentence, consistently within one list.** Fragments take no full stop; sentences do.
- **Bold lead-in for a definition list:** `- **Term** — explanation`, with an em dash. This is the dominant form in the corpus and it makes a scanned list readable.

**Lists are overused.** Three bullets of one clause each are a sentence with commas. A list earns its formatting when items are genuinely parallel and independently scannable.

### 12. Tables

- **Always fully enclosed** — leading and trailing pipe on every row, header and separator included. Verified: **zero non-enclosed rows across 38 files.**
- **No column alignment padding.** Cells are not space-padded to align in the source; the renderer aligns them and padding makes every edit a multi-line diff.
- **Alignment markers only where they earn it** — `:--:` for a column of short symbols, `--:` for numbers. Plain `---` otherwise.
- **A header row is required**, and it names the column rather than restating the subject.

**Use a table when there are two or more dimensions.** Rule-and-reason, option-and-verdict, term-and-definition, path-and-purpose. A single-dimension table is a list, and a table with one row is a sentence.

**Tables must not hold prose.** A cell of three sentences is unreadable at any width; put the prose below the table and keep the cell to a clause.

### 13. Code blocks

- **Fenced, never indented.** Triple backticks.
- **Every fence declares a language.** This mirrors `missing_code_block_language_in_doc_comment`, which ADR-021 enforces on Dart doc comments — the same requirement, applied to the same content in a different file type. **50 of 79 fences currently do not**; see §30.
- **The languages in use, and when each applies:**

  | Tag | For |
  |---|---|
  | `text` | Directory trees, command output, plain diagrams, anything with no language |
  | `bash` | Shell commands |
  | `dart` | Dart source |
  | `yaml` | Configuration |
  | `json` | JSON documents and payloads |
  | `markdown` | Markdown shown as an example |

- **`text` is the correct tag for a directory tree**, not an empty fence. It says "this has no language" explicitly, which is different from "nobody labelled this".
- **Shell examples show the command, not a prompt.** No `$` prefix — it cannot be copied.
- **Long output is trimmed to what makes the point**, with the elision marked.
- **A code block is not a substitute for a sentence.** A fence containing one identifier should be inline backticks.

---

## Language and references

### 14. Language and writing style

- **Plain, declarative English.** Present tense for what is true, past tense only for what happened.
- **Active voice.** "`data/` implements the interfaces `domain/` declares", not "the interfaces are implemented by".
- **State the rule, then the reason.** Every rule in this repository's documentation answers "why" within a sentence or two of stating "what". A rule without a reason is deleted the first time it is inconvenient.
- **British spelling**, matching the existing corpus — *behaviour*, *initialise*, *organisation*, *analyse*. Identifiers keep their own spelling: `initialize`, `Color`, `serialization` are code and are quoted as written.
- **Second person for instructions, third for description.** A runbook says "run this"; a reference says "the router imports".
- **No filler.** "It should be noted that", "in order to", "basically", "simply", "just". "Simply" is the worst of them: it tells a reader who is stuck that they should not be.
- **No unexplained superlatives.** "Best practice" and "clean" are claims with no content. Say what property is gained.
- **Name the failure.** The most useful sentence in a rule is usually the one describing what goes wrong without it, concretely: not "this could cause problems" but "a printed token is a leaked token".
- **Honesty about status is required, not optional.** Where something is unimplemented, unverified, or known broken, the document says so in the same breath. `disaster-recovery.md` marks its own recovery objectives *"PROPOSED, NOT RATIFIED"*; ADR-020 records that its convention is *"binding in writing and unenforced in fact"*. A document that overstates readiness is worse than no document, because it is trusted.

### 15. Terminology consistency

**Volume 0, Chapter 0.3 (the Glossary) is the authority.** It states its own force: *"This glossary is the authoritative definition of every recurring term used across Volumes 0–12. If a later document uses one of these words differently, the later document is wrong and must be corrected — not the other way around."*

**A Glossary term MUST carry its Glossary meaning.** `Session`, `Chunk`, `Chunking`, `Upload Queue`, `Collector`, `Client`, `Project`, `Task`, `Dataset`, `Admin`, `Sample`, `Annotation`, `Metadata`, `Clip`, `Frame` are defined. Using one loosely is a defect in the document.

**Capitalise a defined business term when used in its defined sense.** This is not decoration — for four of them the lowercase form already means something else in this repository, and the collision is live:

| Term | Capitalised means | Lowercase means | Current usage |
|---|---|---|---|
| `Client` | The customer organisation (Glossary) | An HTTP or SDK client — `DioClient`, `S3Client` | 3 upper / 47 lower, all correct |
| `Project` | A body of work assigned to Collectors | This software project, or the Firebase project | 7 upper / 59 lower, all correct |
| `Collector` | The field worker | — | 4 upper / 0 lower |
| `Session` / `Chunk` | The domain entities | A generic recording segment, an HTTP session | Mixed, and context-appropriate |

The repository already does this correctly. It is recorded because it is invisible until someone writes "the client owns the project" and means neither.

**Fixed spellings**, all currently unanimous: `GitHub` (never `Github`), `presigned` (never `pre-signed`), `Riverpod`, `Isar`, `Flutter`, `Dart`, `ap-south-1`. Package names keep their own casing in backticks: `flutter_riverpod`, `isar_flutter_libs`.

**One name per thing.** `Vump Technologies` is the project (ADR-011). "Human Archive" appears only when quoting a source being corrected — verified: all 9 occurrences are in ADR-011 and the amendment register, and every one is a quotation or a statement of what a volume says. That is the exception, and the only one.

### 16. Cross-references

- **Link, do not repeat.** A rule that exists elsewhere is referenced by link. This is §3's one-fact-one-home rule in practice.
- **Cite an ADR by number and name on first use** — "ADR-011", or "ADR-011 (S3 storage architecture)" where the number alone would not orient the reader. A bare number is fine thereafter.
- **Reference a section, not a page** — "Volume 3, Chapter 3.7 §2", "ADR-022 §5.2", "R3". Section references survive a document growing; line numbers do not.
- **State the direction of authority when it matters.** "Fixed by ADR-007" tells the reader they cannot change it here. "See ADR-007" does not.
- **Amendments are cited by their register ID** — `A-025`, `A-029`. The ID is permanent; the entry's status is not.

### 17. Internal links

- **Relative paths**, always. Never a `github.com` URL to a file in this repository — it breaks on a fork, in a clone, and in any editor preview.
- **Link text is the document's name or its path**, not "here" or "this document". Both of these are correct forms — the title, and the path in backticks:

  ```markdown
  [ADR-011](../architecture/decisions/ADR-011-s3-storage-architecture.md)
  [`docs/architecture/README.md`](../architecture/README.md)
  ```

  "Click here" is not. Note that the example above is a fenced block rather than inline: a link-shaped placeholder in prose is indistinguishable from a real link to the checker in §30, and a standard should not break the tool it recommends.
- **Path in backticks when it is a path**, plain when it is a title.
- **Every internal link resolves.** Verified: **zero broken internal links across all 38 files.** This is the single easiest documentation invariant to hold and the easiest to lose — a moved file breaks silently, because nothing fails.

### 18. External links

- **HTTPS only.** Verified: zero `http://` links.
- **Minimise them.** The project's own documentation contains exactly **one** external link — `conventionalcommits.org`, cited twice in ADR-020. The remaining four are in the unmodified Flutter template README. That is close to deliberate self-containment and worth keeping: an external page can change or disappear, and a document that depends on one has a dependency it does not control.
- **Link to a specification, not a blog post.** An RFC, a standard, a vendor's reference documentation. Not a tutorial, not a Stack Overflow answer, not a Medium article.
- **Where an external fact matters, state it in the document and link as corroboration**, so the document still makes sense when the link dies.
- **Never link to an internal tool, dashboard or ticket without saying what it is** — a reader without access must still understand the sentence.

### 19. File naming

Fixed by **ADR-023 §1.4** (documentation files: `kebab-case.md`, `README.md` excepted) and **§1.5** (ADR files). Not restated.

**One addition this document makes:** a reference document is named for its **subject**, not its type. `naming-conventions.md`, not `naming-standards-reference.md`. The directory already says what type it is.

### 20. Directory placement

Fixed by **ADR-022** for the repository tree. Within `docs/`, placement follows the audience:

| Directory | Audience | Contains |
|---|---|---|
| `docs/architecture/` | Anyone changing the system's shape | Decisions, the process that governs them, the registers, architecture references |
| `docs/development/` | Anyone writing code or documents | Standards and practices — this document, `secrets-management.md` |
| `docs/git/` | Anyone committing | Branch and commit practice |
| `docs/operations/` | Anyone responding to an incident | Runbooks and recovery procedures |
| `docs/volumes/` | Anyone tracing a requirement | The source specification PDFs |

**No document sits at the root of `docs/`.** One does — see §30.

**A document about how to build belongs with the audience that builds, not with the architecture it describes.** That is why this document is in `docs/development/` rather than `docs/architecture/`: it governs writing, and its reader is a contributor, not an architect. Its binding decisions are in ADR-024, which is where an architect looks.

### 21. Versioning

**Markdown documents in this repository carry no version number and no revision history block.** Git carries both, exactly and without maintenance: `git log --follow <file>` gives every change, its author, its date, its reason, and the diff.

The Project Constitution §8 requires that *"every document carries a version number and status (Draft / Approved / Superseded) in its Document Control block"*. That requirement is correct for the volumes, which are `.docx`/`.pdf` deliverables outside version control and have no other way to identify their current state. It does not transfer to markdown in git, where a hand-maintained version field is a second source of truth that goes stale the first time someone edits without bumping it. Registered as amendment **A-033**.

**What is carried instead:**

- **ADRs carry `Status` and `Date`** — because `Proposed`/`Accepted`/`Deprecated`/`Superseded` is a *lifecycle state*, not a version, and it determines whether the document is binding. `docs/architecture/README.md` fixes this and it is not optional.
- **Reference documents carry neither**, and state their governing ADR instead. What binds is the ADR; the reference is accurate or it is fixed.
- **Dates are ISO 8601** — `2026-08-11`. Never `11/08/2026`, which two readers will read as two dates.
- **A document describing unratified or unverified state says so in the text**, where a reader will see it — not in a metadata field they will not.

### 22. Examples versus requirements

**An example illustrates a rule. It never defines one.** Confusing the two is how a rule quietly narrows to the case that was written down.

- **State the rule first, in general terms, then illustrate.** Never state a rule only by example.
- **Mark examples as examples** — "for example", "such as", or a labelled code block. Where a list is exhaustive, say so: "the four permitted values are".
- **An example must be real or realistic.** `foo`/`bar` examples teach nothing about this project; every example in this repository's documentation uses real identifiers from the codebase, which also means a rename breaks the example visibly.
- **Show the wrong version too, where the mistake is common.** ADR-023's "common mistake" for every rule exists because a rule stated only positively does not tell the reader what they are about to do wrong.
- **Do not let an example carry a requirement that is stated nowhere else.** If the only place a constraint appears is inside a code sample, it is not a rule, it is an accident.

### 23. RFC 2119 wording

**Declarative present tense is the default. Uppercase RFC 2119 keywords are used only where the strength of a rule would otherwise be genuinely ambiguous.**

The repository currently uses **zero** RFC 2119 keywords across all 38 files, and its rules are not weaker for it: *"Dependencies point inward"* is not less binding than *"dependencies MUST point inward"* — it is shorter and reads as prose.

**The interpretive rule, stated so it is never argued:** a requirement expressed in declarative present tense is a requirement. The absence of `MUST` does not make anything optional.

**Where a keyword is warranted**, it is uppercase and used with its RFC 2119 meaning:

| Keyword | Means | Use when |
|---|---|---|
| `MUST` / `MUST NOT` | Absolute requirement or prohibition | A reader might otherwise read a requirement as advice, or the rule sits beside a `SHOULD` |
| `SHOULD` / `SHOULD NOT` | Strong recommendation; deviation needs a stated reason | There are legitimate exceptions and the writer cannot enumerate them |
| `MAY` | Genuinely optional | A reader might otherwise think something is forbidden |

**`SHALL`, `REQUIRED`, `RECOMMENDED`, `OPTIONAL` and `NOT RECOMMENDED` are not used** — they add synonyms without adding distinctions.

**Never uppercase a keyword for emphasis.** `MUST` in a sentence that is not a requirement destroys the signal everywhere else. Bold is for emphasis.

The most valuable of the three is `SHOULD`, because it is the only one that says *"this has exceptions and you must justify yours"* — which declarative prose cannot express without a paragraph.

### 24. Diagrams

- **ASCII diagrams in a `text` fence.** No image, no external rendering service, no build step. Two exist — ADR-022 §3.5's layer diagram and §3's precedence chain — and both are readable in a terminal, in a diff, and in a plain-text editor.
- **A diagram must add something prose cannot.** Directionality, nesting, and flow are worth drawing. A list of four items in a box is a list.
- **Label every arrow.** An unlabelled arrow between two boxes could mean depends-on, calls, contains or becomes. ADR-022's diagram labels its arrows *implements*, *invokes* and *depends on*, which is what makes it a diagram rather than decoration.
- **Keep it under 80 columns** so it does not wrap in a terminal or a side-by-side diff.
- **Mermaid is not adopted.** It renders on GitHub and nowhere else in this toolchain — not in a terminal, not in a diff, not in a plain editor — so a diagram written in it is invisible in most places this documentation is read. Revisit if the documentation ever gains a rendered site.

### 25. Images

**No images. The repository contains none, and this is the standard, not an accident.**

- An image cannot be diffed, so a change to one is invisible in review.
- An image cannot be searched, so its content is unfindable.
- An image goes stale silently — a screenshot of a UI that has changed is confidently wrong.
- An image is a binary in git history forever, at full size, for every revision.

**Where an image is genuinely required** — a UI reference for a design decision, a screenshot of a console state that cannot be expressed as text:

- It lives in `assets/` at the repository root (ADR-022 §1.8 — *not* `mobile/assets/`, which is for runtime assets the app loads).
- It has descriptive alt text, because alt text is the only part that is searchable and the only part a screen reader gets.
- The document states in prose what the image shows, so the document survives without it.
- It is `.png` or `.svg`. Prefer `.svg`, which diffs as text.

---

## Lifecycle

### 26. Deprecation

**Nothing is deleted. Superseding is recorded, not performed silently.**

The Constitution §8 requires it: *"Superseded documents are retained (not deleted) for history, and clearly marked as superseded with a pointer to the replacement."*

| Document type | How it retires |
|---|---|
| **ADR** | Status becomes `Deprecated` (nothing replaced it) or `Superseded by ADR-NNN`. The file keeps its original name and number forever. The replacing ADR references the one it supersedes. Fixed by `docs/architecture/README.md` |
| **Reference / implementation** | Content is corrected in place. If the whole document is obsolete, it gains a prominent first-line notice naming its replacement, and is removed only once nothing links to it |
| **Amendment entry** | Marked `Applied` with the volume version that carried the correction. **Never deleted** — the trail from original to correction is the point |
| **Runbook** | A procedure that no longer applies is marked obsolete with the date and the reason, not deleted. Someone will find the old system still running |

**A deprecated document must say what to read instead**, on its first line. A reader who finds it via search will not read to the bottom.

**Numbers are never reused.** ADR-NNN and A-NNN are permanent identifiers; a deleted number would make every existing citation ambiguous.

### 27. Amendment process

Two distinct processes, for two distinct things. Confusing them is the most likely governance mistake.

**Changing a volume** follows the Constitution §9, which is not restated here: propose → impact assessment → owner approval → version bump → changelog entry. Because volumes are PDFs and cannot be edited in this repository, a correction discovered during implementation is registered in `docs/architecture/volume-amendments.md` against the ADR that carries authority for it. That register's own header documents the entry format and the discharge rule.

**Changing a decision recorded here** follows the ADR lifecycle in `docs/architecture/README.md`: an accepted ADR is never edited to change its meaning; it is superseded by a new one.

**Changing a rule in a reference document**, where the governing decision is unchanged: edit the document. This is the ordinary case and needs no ceremony — a clarification, a better example, a newly discovered deviation. **If the edit changes what is permitted, it is not a documentation change; it is an amendment to the governing ADR**, and needs a new ADR.

**The test:** would this edit make previously-compliant work non-compliant? Then it is a decision, not an edit.

### 28. Review checklist

For any pull request touching documentation. The `.github/pull_request_template.md` already covers architecture governance, verification and secrets; this checklist is the documentation-specific layer and is applied at review, not by a tool.

- [ ] **Placement** — correct directory for the audience (§20); filename is `kebab-case.md` (ADR-023 §1.4)
- [ ] **One H1**, on line 1, followed by a one-line purpose statement (§9, §4)
- [ ] **Precedence stated** — a non-ADR document says what governs when it conflicts (§3)
- [ ] **No duplication** — every rule stated here is stated nowhere else; everything else is a link (§3, §16)
- [ ] **No heading level skipped**; nothing deeper than `###` (§9)
- [ ] **Every code fence declares a language**; `text` for trees and output (§13)
- [ ] **Tables fully enclosed**; no prose in cells (§12)
- [ ] **Every internal link resolves**; relative paths only (§17)
- [ ] **ADRs cited by number**; sections cited by section, not line (§16)
- [ ] **Glossary terms used with their Glossary meaning**, and capitalised where defined (§15)
- [ ] **Every rule states its reason** (§14)
- [ ] **Status is honest** — unimplemented, unverified and unenforced are labelled as such (§14)
- [ ] **Examples are marked as examples**, and carry no requirement stated nowhere else (§22)
- [ ] **An ADR is included** if the change introduces or alters a decision (§27)
- [ ] **No trailing whitespace**; file ends with a newline (§8)

### 29. Documentation lifecycle

**Documentation is written with the change, not after it.** The Constitution §1 — *"Documentation drives code, not the other way around"* — and `CLAUDE.md`'s governance rule both require it: a mission that introduces an architectural decision updates the relevant ADR or creates one before it is complete.

```text
Decision needed        →  ADR, status Proposed
Decision approved      →  ADR status Accepted; binding from that moment
Rule needs applying    →  Reference document specifies it
Code written           →  Complies, or the code is the defect
Practice diverges      →  Reference document corrected, or a new ADR supersedes
Decision reversed      →  New ADR; the old one is marked Superseded, never edited
```

**Two kinds of drift, with different fixes:**

- **The document is wrong** — practice moved and the document did not. Fix the document.
- **The practice is wrong** — the document is right and the code diverged. Fix the code. `CLAUDE.md`: *"Where code and an accepted ADR disagree, the ADR is correct and the code is a defect."*

Deciding which of the two you are looking at is a governance judgement, not a preference, and getting it backwards is how an architecture erodes: each individual decision to "update the doc to match the code" is defensible, and the sum of them is an architecture nobody chose.

**Documentation is reviewed when the thing it documents changes**, not on a schedule. A calendar review of 38 documents finds typos; a review triggered by a change finds the sentence that is now false.

### 30. Future maintenance and known deviations

**Maintenance rules.**

- **Every mission that changes a documented rule updates the document in the same commit.** A follow-up commit is a commit that does not happen.
- **A new document is registered where readers look** — `docs/architecture/README.md` for architecture documents, the root `README.md` documentation table for everything else. An unregistered document is an unread document.
- **Counts and audit results are re-verified, not copied.** Every number in this document and in ADR-024 was produced by a command against the repository. A stale count is worse than no count because it is quoted.
- **The mechanical rules here are checkable and should become a CI job**: exactly one H1, no skipped heading levels, no fence without a language, no broken internal link, no trailing whitespace, file ends with a newline. All six are a short script over `git ls-files '*.md'`. Not implemented — see the risks in ADR-024.

**Known deviations.** Audited across every tracked markdown file. Recorded rather than fixed by the mission that found them: existing documents are not rewritten wholesale, and accepted ADRs are not modified.

| Deviation | Detail | Disposition |
|---|---|---|
| **49 of 108 code fences declare no language** | Across 26 files, including 13 accepted ADRs. Re-counted in Mission 0.19.12; the previous figure of 50 of 79 was Mission 0.19.4's and the corpus has grown since. Almost all are directory trees or command output, whose correct tag is `text` | Fixed per file when that file is next edited. `docs/architecture/README.md` permits formatting corrections to an accepted ADR, so the ADR cases are eligible — but as a deliberate formatting pass, not as a side effect |
| **`docs/Teams_work.txt`** | Markdown content in a `.txt` file, `Title_Snake` case, at the root of `docs/`. Violates ADR-023 §1.4 and §20. Contents reviewed for this mission: a table allocating AI tools to workstreams — a personal working note, not repository documentation | **Recommend** moving to `docs/development/ai-tooling-allocation.md`, or removing it if it is not meant to be tracked. Not done here: relocating or deleting someone's working note is their call, not a naming fix |
| **`CLAUDE.md` does not end with a newline** | The only file in the repository without one | One-character fix, deliberately not bundled into a documentation mission — `CLAUDE.md` is the constitution and every change to it should be visible on its own |
| **Three documents state no precedence** | `secrets-management.md`, `disaster-recovery.md`, `infrastructure/aws/cloudfront/README.md`. All three are governed by accepted ADRs but do not say what happens on conflict | Added when each is next edited. **Corrected in Mission 0.19.12:** this row previously listed four and named `mobile/README.md`, which the same commit that wrote the row had already fixed — the list was stale on publication. `.github/pull_request_template.md` also lacks one and is now exempt (§3, ADR-032) |
| **ADR-002 has no `Implementation Status`** | The only ADR of 33 without it. It has `Related Missions` | **Not fixed** — adding a section to an accepted ADR is a content change, not a formatting correction. Left as the documented exception |
| **`CLAUDE.md` opens with `## Your Role`** | No one-line purpose statement between the H1 and the first section, unlike every other document | Left as-is. It is the constitution and its first section is its purpose |

**Everything else conforms**, verified by audit. **Re-derived in Mission 0.19.12** — the figures below were previously Mission 0.19.4's and had not been refreshed:

| Audited | Result |
|---|---|
| Tracked markdown files | 57 (excluding one 4-line Flutter platform template) |
| Documents with exactly one H1 | 56 of 57 — the exception is the PR template, correctly |
| Heading level skips | **0** |
| Maximum heading depth | H3, in every file |
| Broken internal links | **0** |
| Non-HTTPS external links | **0** |
| External links in the project's own documentation | 1 (`conventionalcommits.org`, cited twice) |
| Non-enclosed table rows | **0** |
| Lines with trailing whitespace | **0** |
| ADRs with all four required sections, `Status` and ISO `Date` | 33 of 33 |
| ADRs containing a horizontal rule | **0 of 33** — the convention holds exactly |
| ADR filenames matching `ADR-NNN-kebab-case-title.md` | 33 of 33 |
| RFC 2119 keywords in use before this document | **0** |
| Stale "Human Archive" references | **0** — all 9 occurrences are quotations of a source being corrected |
| Terminology variants (`Github`, `pre-signed`, `riverpod` in prose) | **0** |
