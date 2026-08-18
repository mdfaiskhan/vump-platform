variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod (naming-conventions.md §7.1)."
  type        = string
}

variable "region" {
  description = "AWS region. Used to build the integration URI."
  type        = string
}

variable "artifacts_dir" {
  description = <<-EOT
    Directory holding one esbuild bundle per function, as
    <artifacts_dir>/<function>/index.mjs. Produced by `npm run build` in
    backend/. Terraform zips it; it does not build it.
  EOT
  type        = string
}

variable "lambda_role_arns" {
  description = <<-EOT
    Execution role ARNs by function name, from the iam module. Seven roles
    across ADR-015's six domains — the chunks domain carries two, because a
    Lambda has exactly one execution role and A-143 split the privilege.
  EOT
  type        = map(string)
}

variable "db_credential_secret_arns" {
  description = "Per-function database credential secret ARNs, keyed by function name (Mission 6.3). Each function is given only its own."
  type        = map(string)
}

variable "lambda_environment" {
  description = "Non-secret environment variables common to every function. Secret VALUES are forbidden here (Volume 8 Ch. 8.4 §2)."
  type        = map(string)
}

variable "runtime" {
  description = <<-EOT
    Lambda runtime identifier.

    nodejs24.x, chosen in Mission 6.2.1 against what Lambda actually supports:
    nodejs20.x is already deprecated, nodejs22.x deprecates 2027-04-30, and
    nodejs26.x is public preview and documented as not for production. Keep in
    step with backend/package.json's `engines` and scripts/build.mjs's target.
  EOT
  type        = string
  default     = "nodejs24.x"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention. Explicit, because the default is never expire."
  type        = number
  default     = 30
}

variable "lambda_timeout_seconds" {
  description = <<-EOT
    Default Lambda timeout, in seconds, for every function without an override.

    **28 is PROVISIONAL, not final.** It is the largest value that can be
    reached through API Gateway today, and it is deliberately lower than what
    AWS recommends for this cluster's configuration. An account-level request
    to raise the API Gateway REST integration-timeout quota to ~35-40s is with
    AWS; when it is granted, this default and the `validation` ceiling below
    both rise together, to a value with real margin above AWS's documented
    30-second deep-sleep figure. Until then this number is a ceiling imposed by
    a quota, not a judgement about how long a request should take, and it
    should not be cited as one.

    28, not 15, and the value is derived rather than rounded.

    **What forced the change.** Gap 9 / A-178: two calls on CPH2707 measured
    15876ms and 15889ms against the old 15000ms and returned 502, because
    Aurora was resuming from `min_capacity = 0`. That is not a slow request —
    until Mission 7.2 it ended the user's session.

    **What AWS documents.** The Aurora Serverless v2 auto-pause guide gives two
    figures, and the second is the one that governs here:

      * "Because the typical time to resume might be approximately 15 seconds,
        we recommend that you adjust any client timeout settings to be longer
        than 15 seconds."
      * "If an Aurora serverless instance remains paused more than 24 hours,
        Aurora can put the instance into a deeper sleep that takes longer to
        resume. In that case, the resume time can be **30 seconds or longer** …
        we recommend setting connection timeouts to **30 seconds or more**."

    `seconds_until_auto_pause` is unset on this cluster, so it takes AWS's
    300-second default and the cluster pauses five minutes after the last call.
    Development runs in mission-length bursts days apart, so the **deep-sleep
    path is this environment's normal case, not its tail.**

    **Why 28 and not the 30+ AWS asks for.** API Gateway's REST integration
    timeout is 29 seconds and this module sets no `timeoutInMillis`, so 29 is
    the ceiling a request can reach through the API at all. A Lambda timeout
    above it is unreachable. 28 sits one second under, so the *function's* own
    timeout fires first and CloudWatch records which function and which route,
    rather than API Gateway returning an opaque 504 with nothing on the
    function side.

    **So this does not close gap 9, and must not be read as closing it.** The
    old 15000ms sat *below* the 15889ms that was measured against it — 0.94x,
    which is why it failed. 28000ms is 1.76x that observation, and still short
    of the 30s AWS recommends for a cluster idle more than a day, which this
    one routinely is. Closing gap 9 needs a decision this variable cannot
    express — raise the API Gateway integration quota above 29s, or stop
    `min_capacity` being 0.

    ## What the raised value must be checked against — NOT either figure alone

    Mission 7.3 measured two costs against this ceiling, and the question is
    whether they stack inside one invocation:

      * **Aurora resume** — up to 15s typical, "30 seconds or longer" after 24h
        idle (AWS). Gap 9.
      * **The chunk hash** — 7780ms at 1769MB, measured. F4.

    **Traced against the designed flow, they do not stack in `chunks-verify`,
    and the reason is ADR-048.** The REQUEST authorizer is `auth-verify`, it
    runs on every request because `authorizerResultTtlInSeconds = 0`, and it
    reads `users` over the Data API *before* API Gateway invokes the target
    function. So the first Data API call of any request belongs to the
    authorizer, and **the authorizer pays the resume.** By the time
    `chunks-verify` runs, the cluster is awake and cannot re-pause beneath it —
    auto-pause needs 300s idle and the hash takes eight seconds.

    `chunks-verify`'s own worst case is therefore hash + warm queries, roughly
    9-10s, comfortable at 28.

    **The stacking risk is real but it lives in `auth-verify`, not here.** That
    function is the one that must absorb a deep-sleep resume inside a single
    invocation, on this same 28s ceiling, against AWS's 30s figure — one
    function, on the critical path of all fourteen authorized routes.

    So the raised ceiling should be sized on **the authorizer's resume worst
    case**, and `chunks-verify`'s hash checked separately as a second, smaller
    budget rather than added to it. ~40s covers both readings and is a safe
    target either way; the distinction matters because it says *which* function
    to watch.

    **This is a design-level trace, not a measurement**, taken before the
    handlers exist. If the built `PATCH /v1/chunks/{chunkId}/status` ever
    issues its first Data API call on a path the authorizer did not precede —
    an S3-event-triggered verification, say, which Chapter 4.10 §2 step 3
    explicitly permits — then the two costs **do** stack in one invocation and
    this paragraph is wrong. Re-check it when that handler is built.
  EOT
  type        = number
  default     = 28

  validation {
    # Above 29 the value is a fiction: API Gateway REST integrations cut off at
    # 29 seconds by default, so a larger Lambda timeout is never reached
    # through the API. Failing here beats a number that looks generous and is
    # unreachable.
    #
    # **Raise this ceiling when — and only when — the quota increase is
    # granted.** It is pinned to an AWS account limit, not to a design opinion,
    # so the two must move together: raising the default without raising this
    # fails the plan, and raising this without the quota reinstates exactly the
    # unreachable-timeout problem it exists to prevent.
    condition     = var.lambda_timeout_seconds > 0 && var.lambda_timeout_seconds <= 29
    error_message = "lambda_timeout_seconds must be 1-29. API Gateway REST integrations time out at 29s unless the account quota is raised, so anything larger is unreachable through the API. If the quota has been raised, raise this ceiling in the same change."
  }
}

variable "lambda_memory_mb" {
  description = <<-EOT
    Default Lambda memory, in MB, for every function without an override.

    512 is unchanged from Mission 6.2 and still right for Chapter 4.6's small
    reads and writes. It is now a variable rather than a literal so that a
    function with a different workload can say so — see `lambda_overrides`.
  EOT
  type        = number
  default     = 512
}

variable "lambda_overrides" {
  description = <<-EOT
    Per-function timeout and memory, keyed by function name. Absent keys and
    absent attributes fall back to `lambda_timeout_seconds` / `lambda_memory_mb`.

    **Why this exists.** Until now `timeout` and `memory_size` were literals
    inside a `for_each` over all seven functions, so every function was sized
    for the same imagined workload. That was defensible while all seven did
    small reads and writes. It stops being defensible at `chunks-verify`, which
    Volume 4 Chapter 4.5 §3 makes responsible for verifying a chunk's
    `checksum_sha256` against the uploaded object — and Mission 3.8.1 measured a
    real full chunk at **633,232,477 bytes**.

    Memory is the lever that matters there and not for the reason it usually is:
    a streaming SHA-256 over a `GetObject` body is O(1) in object size, so 512MB
    already suffices to *hold* the work. Lambda allocates network and CPU in
    proportion to memory, so memory buys **throughput**, and throughput is what
    decides whether the hash finishes inside API Gateway's 29 seconds.

    Sized against a measurement rather than a guess — see the `chunk-hash-probe`
    function in the dev environment, whose whole purpose is to produce that
    number.
  EOT
  type = map(object({
    timeout_seconds = optional(number)
    memory_mb       = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for o in values(var.lambda_overrides) :
      o.timeout_seconds == null || (o.timeout_seconds > 0 && o.timeout_seconds <= 29)
    ])
    error_message = "An override's timeout_seconds must be 1-29, for the same API Gateway reason as lambda_timeout_seconds."
  }
}
