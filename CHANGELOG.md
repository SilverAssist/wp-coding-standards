# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.5] - 2026-08-13

### Fixed

- Removed the static `"version"` field from `composer.json`. Packagist
  treats an explicit `version` field as authoritative and silently skips
  any tag whose name doesn't match it — since this field was left at
  `1.1.0` through the 1.1.1-1.1.4 tags, **none of those releases (including
  the critical fix above) ever actually reached Packagist**, and every
  consumer's `composer update` kept silently resolving back to the buggy
  1.1.0. Composer infers the version from the git tag on its own; a static
  field is discouraged for exactly this reason.

## [1.1.4] - 2026-08-13

### Fixed

- **Critical**: `run-quality-checks.sh`'s check functions (`run_composer_validate`,
  `run_phpcs`, `run_phpstan`, `run_phpunit`, `run_syntax_check`, shipped in
  1.1.0-1.1.3) each ran the real command, then unconditionally printed a
  success message as the function's last statement — which became the
  function's return value regardless of whether the real command actually
  failed. Combined with a `set -e`-inside-a-`||`-checked-call bash gotcha,
  this meant **every check silently reported success even when it failed**.
  Found via a real false-green CI run on `paubox-cf7`'s first adoption PR,
  where `vendor/bin/phpunit` fatally errored but the job still showed
  "✅ All quality checks passed!". Every function now explicitly checks its
  command's exit code and returns/reports accordingly. If any repo adopted
  the reusable workflow between 1.1.0 and this fix, re-run its CI.
- `run_phpunit()` now exports `TESTSUITE=integration` whenever WP setup ran
  — some consumers' `tests/bootstrap.php` gate `WP_UnitTestCase` loading
  behind that variable so local unit-only runs can skip WP entirely;
  without it, those repos' integration tests silently never ran under the
  bug above, and would now correctly fail without this companion fix.

## [1.1.0] - 2026-08-13

### Added

- `scripts/install-wp-tests.sh` and `scripts/run-quality-checks.sh` —
  shared, invoked directly from `vendor/` by consumer repos (no local
  copy needed). The reusable `quality-checks.yml` workflow now calls
  these instead of expecting a local `scripts/` copy in the consumer.
- `run-quality-checks.sh` auto-detects the main plugin file and source
  directory (`includes/`, `Includes/`, or `src/`) so one script serves
  every consumer without per-repo forks.

### Fixed

- `install-wp-tests.sh` carried three bugs found via Copilot review on
  earlier per-repo copies, now fixed at the source: a path-existence
  check that looked in the caller's cwd instead of `$WP_TESTS_DIR`;
  `set -ex` tracing `$DB_PASS` into CI logs; and a dependency on a
  mutable third-party `db.php` drop-in that was never actually needed
  given native `mysqli`/`pdo_mysql` support.

### Documentation

- Corrected `AGENTS.md`'s consumer-migration-status notes — the PHPCS
  ruleset migration is now complete on every plugin repo except
  `wp-github-updater`.

## [1.0.0] - 2026-08-12

### Added

- Initial `SilverAssistWP` PHPCS ruleset (`WordPress-Extra` + `WordPress-Docs`
  + naming/i18n extras), extracted from `SILVERASSIST_STANDARDS.md` and
  cross-checked against `wp-settings-hub`/`silver-assist-post-revalidate`.
- Initial PHPStan config composing `silverassist/coding-standards`.
- Reusable `quality-checks.yml` GitHub Actions workflow plus `ci.yml`/
  `release.yml` templates for consumer plugin repos.
- `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md` for AI coding agents.

Validated against two real, materially different consumers before
release: `silver-assist-post-revalidate` (byte-identical `phpcs` output
before/after the swap) and `contact-form-to-api` (223 new violations
found and fully remediated, not suppressed — a real stress test of the
stricter ruleset against a repo that had drifted furthest from it).
