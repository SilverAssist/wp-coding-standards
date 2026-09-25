# Silver Assist WordPress Coding Standards

WordPress-plugin PHPCS ruleset, PHPStan config, and reusable CI/CD
workflows shared by all Silver Assist WordPress plugins. Requires
[`silverassist/coding-standards`](https://github.com/SilverAssist/coding-standards)
for the framework-agnostic base (PHPStan level 8 + excludePaths); the PHPCS
side stays independent (see "Why not compose PHPCS rules" below).

## Install

```bash
composer require --dev silverassist/wp-coding-standards
```

## Installing via Composer (private repository)

SilverAssist packages are installed from their GitHub repositories with a Composer
`vcs` repository, not from Packagist.org. Those repositories can require
authentication, so always configure a token.

1. **Declare the repository** in your project's root `composer.json`. Composer only
   reads `repositories` from the root package, so every SilverAssist package your
   project needs must be listed there, including transitive ones:

   ```json
   {
     "repositories": [
       { "type": "vcs", "url": "https://github.com/SilverAssist/wp-coding-standards", "no-api": true },
       { "type": "vcs", "url": "https://github.com/SilverAssist/coding-standards", "no-api": true }
     ],
     "require-dev": {
       "silverassist/wp-coding-standards": "^1.0"
     }
   }
   ```

2. **Authenticate** with a GitHub token that can read the repository:
   - Locally: `composer config --global github-oauth.github.com <token>`
   - CI: set `COMPOSER_AUTH='{"github-oauth":{"github.com":"<token>"}}'` from a secret
     (a GitHub Actions secret or a Bitbucket variable).

   Never commit a token or an `auth.json`. Without a token, Composer hits GitHub's
   anonymous API limit (60 requests per hour per IP) and falls back to an SSH clone.

   Keep `"no-api": true` on every `vcs` entry: it makes Composer read tags with git instead of
   the GitHub API. Without it, one install without a lock file costs about 100 API requests of
   the token's hourly quota (5,000, shared with the token owner's other API usage), which a busy
   CI can exhaust.

3. **Refresh the lock file** if your project commits `composer.lock`: run
   `composer update --lock` after adding `repositories`, so the lock file's
   `content-hash` matches `composer.json`.

This repository's own `composer.json` declares `vcs` repositories for its SilverAssist development dependencies (`coding-standards`), so contributors and CI need the same token.

### Troubleshooting

| Symptom | Cause |
|---------|-------|
| `Failed to clone the git@github.com:SilverAssist/wp-coding-standards.git repository, try running in interactive mode...` followed by `Permission denied (publickey)` | The token is missing or has no access to the repository. |
| `remote: Invalid username or token` | The token is invalid or expired. |
| `it could not be found in any version` | The `vcs` entry is missing from the root `composer.json`. |

## Usage — PHPCS

```xml
<?xml version="1.0"?>
<ruleset name="YourPlugin">
    <file>.</file>
    <exclude-pattern>*/vendor/*</exclude-pattern>
    <exclude-pattern>*/node_modules/*</exclude-pattern>
    <exclude-pattern>*/tests/*</exclude-pattern>

    <rule ref="SilverAssistWP"/>

    <!-- Plugin-specific: PrefixAllGlobals must be declared per-plugin,
         it can't live in the shared ruleset. -->
    <rule ref="WordPress.NamingConventions.PrefixAllGlobals">
        <properties>
            <property name="prefixes" type="array">
                <element value="your_plugin_prefix"/>
                <element value="SilverAssist\YourPlugin"/>
            </property>
        </properties>
    </rule>
</ruleset>
```

## Usage — PHPStan

Include all three files directly — `phpstan/base.neon` in this package
deliberately does not chain-include `silverassist/coding-standards` or
`szepeviktor/phpstan-wordpress` itself (relative `includes:` paths break
once this file is consumed as a dependency rather than run as a project
root; see that file's own comments for why):

```yaml
includes:
    - vendor/silverassist/coding-standards/phpstan/base.neon
    - vendor/silverassist/wp-coding-standards/phpstan/base.neon
    - vendor/szepeviktor/phpstan-wordpress/extension.neon

parameters:
    paths:
        - includes
    bootstrapFiles:
        - your-plugin-main-file.php
```

If your test suite uses `silverassist/wp-plugin-kernel`'s `Testing\TestCase`
(which extends `WP_UnitTestCase`), also add:

```yaml
    paths:
        - includes
        - tests
    scanFiles:
        - vendor/php-stubs/wordpress-tests-stubs/wordpress-tests-stubs.php
```

**`scanFiles`, not `stubFiles`** — `WP_UnitTestCase` has no real declaration
anywhere else for `stubFiles` to refine; `scanFiles` parses the stub
package's declarations directly into PHPStan's symbol table, which is
what's needed when nothing else provides the class. Using `stubFiles`
here silently fails with `Class ... extends unknown class WP_UnitTestCase`
— found by testing both directives directly.

## Usage — CI/CD

Copy `templates/workflows/ci.yml` and `templates/workflows/release.yml`
into your plugin's `.github/workflows/`. Both call this package's reusable
`quality-checks.yml` via:

```yaml
uses: SilverAssist/wp-coding-standards/.github/workflows/quality-checks.yml@v1
```

so the actual check logic (PHP version matrix, WordPress Test Suite setup,
Codecov upload) lives in one place instead of being copy-pasted per
plugin — before this package, every plugin's `ci.yml`/`quality-checks.yml`
was a near-identical hand copy that could silently drift.

### Authenticating Composer in CI

The plugins install the SilverAssist packages from their GitHub repositories
(see "Installing via Composer"), so the `composer install` inside the
reusable workflow needs a token. Store the JSON
`{"github-oauth":{"github.com":"<token>"}}` as a repository secret named
`COMPOSER_AUTH` and pass it to the reusable workflow with `secrets: inherit`
(the templates already do). The secret is optional in the workflow, so a
caller that does not pass it keeps working while its repositories are public.
The templates also set `COMPOSER_AUTH` on their own `composer install` steps.

## Usage — Shared Scripts

`scripts/install-wp-tests.sh` and `scripts/run-quality-checks.sh` live in
this package — the reusable `quality-checks.yml` workflow above calls
them straight from `vendor/`:

```bash
bash vendor/silverassist/wp-coding-standards/scripts/install-wp-tests.sh wordpress_test root '' localhost latest
bash vendor/silverassist/wp-coding-standards/scripts/run-quality-checks.sh
```

For anything in the consumer repo that isn't the reusable workflow
itself — a CI job defined directly in the consumer's own `ci.yml` (see
`templates/workflows/ci.yml`'s `compatibility` job), a `composer.json`
script, local dev docs, or a `CONTRIBUTING.md` — add a thin wrapper at
`scripts/install-wp-tests.sh` / `scripts/run-quality-checks.sh` instead
of calling the `vendor/` path directly:

```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../vendor/silverassist/wp-coding-standards/scripts/run-quality-checks.sh" "$@"
```

This keeps `./scripts/run-quality-checks.sh` working for every existing
doc and dev habit without each consumer maintaining a real copy of the
script's logic — only these 4 lines are consumer-owned, not the ~300
lines of actual behavior.

`run-quality-checks.sh` auto-detects the main plugin file (the root
`*.php` file with a `Plugin Name:` header) and the source directory
(first of `includes/`, `Includes/`, `src/` that exists — override with
`SOURCE_DIR` if a plugin uses something else). Run `--help` for the full
option list.

`scripts/build-release.sh` and `scripts/update-version-simple.sh` are
**not** included here yet — consuming plugins currently use genuinely
different release-build strategies (explicit include-list with asset
validation vs. rsync-with-excludes), and unifying them needs a design
decision on which strategy becomes canonical, not just a file move. Each
plugin still keeps its own copy of those two for now.

## Why not compose PHPCS rules from `silverassist/coding-standards`

`WordPress-Extra`'s formatting conventions (tabs, brace placement,
spacing) are a genuinely different, incompatible standard from PSR-12.
Layering both rulesets would produce contradicting sniffs, not a clean
superset. This package requires `silverassist/coding-standards` for the
**PHPStan** composition and to pin both packages' tooling versions
together — not for PHPCS rule stacking. See
`SilverAssistWP/ruleset.xml`'s own description for the full reasoning.

## See also

- [`AGENTS.md`](AGENTS.md) — instructions for AI coding agents working in
  this repo.
