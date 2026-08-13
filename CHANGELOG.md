# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
