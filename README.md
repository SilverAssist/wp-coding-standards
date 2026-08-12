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
