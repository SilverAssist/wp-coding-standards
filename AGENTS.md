# AGENTS.md — silverassist/wp-coding-standards

Instructions for AI coding agents (Claude Code, GitHub Copilot, Codex, or
any other) picking up work in this repo.

## What this repo is

The WordPress-plugin layer of Silver Assist's coding-standards split:

1. `SilverAssistWP/ruleset.xml` — a PHPCS ruleset (`WordPress-Extra` +
   `WordPress-Docs` + naming/i18n extras).
2. `phpstan/base.neon` — composes `silverassist/coding-standards`' base
   and adds the WordPress stubs extension.
3. `.github/workflows/quality-checks.yml` — a reusable `workflow_call`
   target consumer plugins call via
   `uses: SilverAssist/wp-coding-standards/.github/workflows/quality-checks.yml@v1`.
4. `templates/workflows/` — copy-paste entry-point workflows
   (`ci.yml`, `release.yml`) for consumer repos.

Requires `silverassist/coding-standards` — for the PHPStan composition and
version pinning, **not** for PHPCS rule stacking. Read that package's own
`AGENTS.md` and this repo's `README.md` ("Why not compose PHPCS rules")
before assuming the two rulesets should be merged; they deliberately
aren't (WordPress-Extra and PSR-12 are incompatible formatting
conventions).

Released as v1.0.0, validated against two real, materially different
consumers before release: `silver-assist-post-revalidate` (already had
the richest local ruleset variant — byte-identical `phpcs` output
before/after the swap) and `contact-form-to-api` (the minimal
`WordPress-Extra`+`I18n` variant — adopting `SilverAssistWP` surfaced 223
real violations, all fixed, not suppressed). `wp-settings-hub` also
adopted the PHPCS side (its PHPStan setup is deliberately hand-rolled and
was left alone — see "Migrating a consumer repo" below for why that
matters). `leadgen-app-form`, `leadcapture-form`, `silver-assist-security`,
and `wp-github-updater` are still on their own local rulesets as of this
release — same migration playbook applies to each.

## Ground truth for "is this ruleset correct"

`SilverAssistWP/ruleset.xml` was extracted from
`~/Downloads/SILVERASSIST_STANDARDS.md` (section 4.1) and cross-checked
against the two real repos that already implement its richest variant:
`/Users/miguel/Projects/wp-settings-hub/phpcs.xml` and
`/Users/miguel/Projects/silver-assist-post-revalidate/phpcs.xml`. When in
doubt about a rule, check those first — this package should make their
config obsolete, not diverge from it without a documented reason.

## Migrating a consumer repo — checklist

1. `composer require --dev silverassist/wp-coding-standards`.
2. Replace the repo's inline `WordPress-Extra`-based rules with
   `<rule ref="SilverAssistWP"/>` + that repo's own `PrefixAllGlobals`
   properties (these are plugin-specific and can't live in the shared
   ruleset).
3. Replace `phpstan.neon`'s hand-written `parameters:` with three
   top-level `includes:` entries — `silverassist/coding-standards`'s
   `phpstan/base.neon`, this package's own, and
   `szepeviktor/phpstan-wordpress`'s `extension.neon` — keeping only the
   repo-specific `paths`/`bootstrapFiles`. Not a single chained include:
   see `phpstan/base.neon`'s own comments for why relative paths inside a
   shared neon file break once it's consumed as a dependency.
4. Copy `templates/workflows/ci.yml` (and `release.yml` if the repo's
   differs meaningfully from the template). Check the target repo's
   actual default branch first (`main` vs `master`) and update the
   template's `branches:` filters to match, or the new jobs silently
   never run — found this the hard way on `silver-assist-post-revalidate`
   via PR review, not before pushing.
5. Run `vendor/bin/phpcs` and `vendor/bin/phpstan` **before and after** —
   diff the violation list. For repos moving from a weaker base
   (`WordPress-Core`, or the minimal `WordPress-Extra`+`I18n` set), expect
   genuinely new violations to fix, not just a clean config swap — budget
   real time (`contact-form-to-api` found 223).
6. Don't assume the PHPStan side always applies cleanly: `wp-settings-hub`
   hand-rolls its own WordPress stub handling (raw `wordpress-stubs`
   `bootstrapFiles` + a curated `ignoreErrors` list) instead of using
   `szepeviktor/phpstan-wordpress`, and composing this package's shared
   `excludePaths: [tests/*]` would have silently stopped it from
   analysing `tests/` at all — it deliberately excludes only one file
   there, not the whole directory. Diff the *effective* config, not just
   the resulting error count, before deciding a phpstan.neon change is
   safe for a given repo.

## Commit and PR conventions

Conventional Commits, semantic versioning tags, `CHANGELOG.md` per
[Keep a Changelog](https://keepachangelog.com/). A ruleset/workflow change
here is a breaking change for every downstream plugin's CI the moment
it's tagged — never silently edit an already-tagged version.

## Related repos

- `../coding-standards` — the framework-agnostic base this package
  requires.
- `../wp-plugin-kernel` — the `LoadableInterface` architecture package,
  same standardization effort, unrelated to coding style.
- The 7 consumer plugin repos: `../silver-assist-post-revalidate` and
  `../contact-form-to-api` (migrated), `../wp-settings-hub` (PHPCS side
  only, see above), `../wp-github-updater`, `../leadgen-app-form`,
  `../leadcapture-form`, `../silver-assist-security` (not yet migrated).
