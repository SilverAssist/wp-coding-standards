# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
