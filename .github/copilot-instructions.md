# GitHub Copilot Instructions for Silver Assist WP Coding Standards

## Project Context

This is **silverassist/wp-coding-standards**, a Composer package providing
the WordPress-plugin PHPCS ruleset, PHPStan config, and reusable CI/CD
workflows shared across all Silver Assist WordPress plugins. Requires
`silverassist/coding-standards` for the framework-agnostic PHPStan base
and version pinning (not for PHPCS rule composition — WordPress-Extra and
PSR-12 are incompatible formatting conventions, see `README.md`).

### Architecture

- **Deliverable**: configuration + reusable GitHub Actions workflows, no
  plugin runtime code.
- **Type**: `phpcodesniffer-standard`.
- **License**: PolyForm Noncommercial 1.0.0
- **Namespace**: none — this package has no PHP classes.

## File Structure

```
wp-coding-standards/
├── SilverAssistWP/
│   └── ruleset.xml              # WordPress-Extra + Docs + naming/i18n
├── phpstan/
│   └── base.neon                # Composes silverassist/coding-standards
├── .github/workflows/
│   └── quality-checks.yml       # Reusable workflow_call target
├── templates/workflows/
│   ├── ci.yml                   # Copy-paste entry point for consumers
│   └── release.yml
├── scripts/                     # Not yet vendored — see AGENTS.md
├── composer.json
├── AGENTS.md                     # Full instructions for AI coding agents
└── README.md                     # Consumer-facing usage docs
```

## Development Workflow

1. Read `AGENTS.md` first — it has the migration checklist and notes on
   which of the 7 consumer plugins have adopted this package so far.
2. Any ruleset/workflow change here is a breaking change for every
   downstream plugin's CI the moment it's tagged.
3. Update `CHANGELOG.md` per [Keep a Changelog](https://keepachangelog.com/).

## Related Projects

- **coding-standards**: the framework-agnostic base this package requires.
- **wp-plugin-kernel**: the `LoadableInterface` architecture package, same
  initiative, unrelated to coding style.
- **The 7 consumer plugins**: `silver-assist-post-revalidate` and
  `contact-form-to-api` (migrated), `wp-settings-hub` (PHPCS side only),
  `wp-github-updater`, `leadgen-app-form`, `leadcapture-form`,
  `silver-assist-security` (not yet) — see `AGENTS.md` for details.
