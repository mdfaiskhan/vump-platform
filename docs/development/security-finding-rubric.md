# Security Finding Rubric

Four categories and a severity note each, so a security pass has somewhere to start instead of reasoning from scratch every time.

**Authority: none.** This is a working aid, not policy. Volume 11 Chapter 11.4's Risk Register is the register this project will eventually keep; nothing here replaces it, and if it and this disagree, it wins.

**Why it is deliberately small.** Missions 5.7 and 6.7 both reasoned case by case with no scale at all. That is defensible twice and stops being defensible on the third pass, when "how bad is this" starts getting answered inconsistently because nobody wrote the question down. What follows is the smallest thing that fixes that. It is not a framework, it has no scoring, and it should not grow one until something forces it.

---

## The four categories

### Data exposure
Someone can read or write data they are not entitled to.

Tenant isolation, authorization gaps, injection, anything that crosses an org boundary. **Usually the most severe class**, because it is the one the product exists to prevent — Volume 1's BR-19 and BR-20 are both data-exposure rules.

### Credential exposure
A credential, or a path to one, is reachable by something that should not reach it.

Committed secrets, over-broad IAM, a long-lived key where a short-lived one would do, a credential in a log. **Severity scales with blast radius and with reversibility**: a leaked value that can be rotated is bad, one that is disclosed permanently — anything in git history — is worse, and one that grants administrative rights over everything is worst.

### Availability
The system stops working, or can be made to.

Cold-start timeouts, unbounded retries, a dependency with no fallback. **Usually the least severe of the four for this product**, because Collectors record locally and upload later — Volume 5's whole design tolerates the backend being briefly unreachable. That tolerance is what makes this class lower, and it is worth re-checking rather than assuming.

### Governance drift
The record and the reality disagree.

An ADR describing a property the code does not have, a check that does not run, a standard written and never executed, a claim that was never tested. **Severity is not the drift itself but what it conceals**: drift about a formatting rule is noise, drift about an authentication boundary is a security finding, because everyone downstream reasons from the record.

This is the class A-148, A-153, A-161 and gap 16 all belong to, and the one most likely to be under-rated, because nothing is broken *yet*.

---

## The rule that matters more than the categories

**State the evidence class before stating the severity.** Every finding is one of:

| Class | Meaning |
|---|---|
| **Tested** | Observed to happen, with the observation recorded |
| **Inferred** | Follows from configuration or code that was read, but was not run |
| **Reported** | Someone else's claim, not re-checked |

An inferred finding is a **hypothesis with a citation**, and it must be labelled as one until it is tested. This is not pedantry; it is the specific failure Mission 6.7 made — see below.

---

## Worked example — Mission 6.7's own findings

| Finding | Category | Evidence class | Note |
|---|---|---|---|
| **A** — unscoped `faisal-admin` created all 67 resources, 9 migrations, 7 passwords | Credential exposure | **Tested** — `aws sts get-caller-identity` | Highest on the register: maximum blast radius, and production shares the account |
| **A** — CI cannot verify live state (gaps 8, 16) | Governance drift | **Tested** — CI runs no `plan`; `validate` succeeded while `plan` warned | Drift about an authentication boundary, so not noise |
| **C** — Mission 6.4/6.5 auth changes had no CHANGELOG Security entry | Governance drift | **Tested** — searched, 0 matches | Low harm, real: it breaks the method a prior review used |
| **B** — a plaintext password can reach CloudWatch | Credential exposure | **Inferred, reported as if tested — and wrong** | See below |
| Gap 6 — one shared tenant for self-signup | Data exposure | **Tested** — one `orgs` row | Deferred with a trigger, and the trigger is a business event nothing observes |
| Gap 9 — Aurora cold start vs 15s Lambda timeout | Availability | **Tested** — observed in 6.3 and 6.5 | Lower class, and the upload design tolerates it |

### Finding B, and why this rubric exists

**Claimed:** Aurora exports `postgresql` logs to CloudWatch and `log_min_error_statement = error`, therefore a failed `ALTER ROLE … PASSWORD` in `bootstrap.ts` writes the plaintext password to CloudWatch.

**Both premises were read from live configuration and are true.** The conclusion was never run.

**Tested afterwards** (A-169): a deliberately failing `ALTER ROLE` with a marked password, with no protection at all, does **not** appear in the log group — nor does an ordinary failing `SELECT`. Statements issued through the RDS Data API do not surface their text into the Postgres error log, and the Data API is the only path `bootstrap.ts` uses.

**What the rubric would have caught.** Labelling it *inferred* forces the next question — *has anyone run it?* — before severity is assigned. Instead it was written up beside findings that had been tested, in the same voice, and read as equally established. A fix was authorised for it.

**The lesson is not "test more".** It is that an untested inference and an observed fact must not be reported in the same register without the difference visible on the face of it.
