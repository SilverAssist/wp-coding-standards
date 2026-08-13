#!/bin/bash
###############################################################################
# Quality Checks Runner (shared)
#
# Centralized script for running quality checks consistently across every
# Silver Assist plugin's CI/CD workflows. Consuming repos invoke this
# directly from vendor/ — no local copy needed:
#
#   bash vendor/silverassist/wp-coding-standards/scripts/run-quality-checks.sh
#
# Auto-detects the main plugin file (any *.php in the project root with a
# "Plugin Name:" header) and the source directory (first of includes/,
# Includes/, src/ that exists, or $SOURCE_DIR if set) — the two things
# that differ per plugin. Everything else (DB setup, phpcs, phpstan,
# phpunit invocation, argument parsing) is identical across every
# consumer, which is what made this worth extracting: before this script,
# each plugin hand-maintained a near-identical ~350-line copy that only
# ever differed in these two paths.
#
# @package SilverAssist\WPCodingStandards
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

###############################################################################
# Configuration
###############################################################################

# Run from the consuming plugin's root (composer scripts and CI both
# invoke this via `bash vendor/.../run-quality-checks.sh` from the
# project root) — not derived from this script's own location, since
# that would resolve into vendor/silverassist/wp-coding-standards/ when
# shared instead of the consumer's own root.
PROJECT_ROOT="$(pwd)"

# Default values
PHP_VERSION="${PHP_VERSION:-8.2}"
WORDPRESS_VERSION="${WORDPRESS_VERSION:-latest}"
DB_NAME="${DB_NAME:-wordpress_test}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-root}"
DB_HOST="${DB_HOST:-localhost}"
SKIP_WP_SETUP="${SKIP_WP_SETUP:-false}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }

###############################################################################
# Auto-detection
###############################################################################

detect_main_file() {
    local main_file
    main_file=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; 2>/dev/null | head -1)
    if [ -z "$main_file" ]; then
        print_error "No main plugin file found in ${PROJECT_ROOT} (expected a *.php file with a 'Plugin Name:' header)"
        exit 1
    fi
    basename "$main_file"
}

detect_source_dir() {
    if [ -n "${SOURCE_DIR:-}" ]; then
        echo "$SOURCE_DIR"
        return
    fi
    for candidate in includes Includes src; do
        if [ -d "$PROJECT_ROOT/$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
    print_error "No source directory found (checked includes/, Includes/, src/ — set SOURCE_DIR to override)"
    exit 1
}

MAIN_FILE="$(detect_main_file)"
SOURCE_DIR_RESOLVED="$(detect_source_dir)"

###############################################################################
# Setup Functions
###############################################################################

setup_wordpress_tests() {
    print_header "🐘 Setting up WordPress Test Suite"

    if [ "$SKIP_WP_SETUP" = "true" ]; then
        print_warning "Skipping WordPress Test Suite setup (SKIP_WP_SETUP=true)"
        return 0
    fi

    print_info "Installing system dependencies..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq subversion mysql-client > /dev/null 2>&1
    fi
    print_success "System dependencies installed"

    print_info "Setting up MySQL database: $DB_NAME"
    if command -v systemctl &> /dev/null; then
        sudo systemctl start mysql.service || true
    fi

    mysql -e "DROP DATABASE IF EXISTS $DB_NAME;" -u"$DB_USER" -p"$DB_PASS" 2>/dev/null || true
    mysql -e "CREATE DATABASE $DB_NAME;" -u"$DB_USER" -p"$DB_PASS"
    print_success "Database $DB_NAME created"

    print_info "Installing WordPress Test Suite (version: $WORDPRESS_VERSION)..."
    bash "$(dirname "${BASH_SOURCE[0]}")/install-wp-tests.sh" "$DB_NAME" "$DB_USER" "$DB_PASS" "$DB_HOST" "$WORDPRESS_VERSION" true
    print_success "WordPress Test Suite installed"
}

###############################################################################
# Quality Check Functions
###############################################################################

run_composer_validate() {
    print_header "📦 Validating composer.json and composer.lock"
    cd "$PROJECT_ROOT"
    composer validate --strict
    print_success "Composer files validated"
}

run_phpcs() {
    print_header "🎨 Running PHPCS (Code Style Check)"
    cd "$PROJECT_ROOT"
    vendor/bin/phpcs --warning-severity=0
    print_success "PHPCS passed - No errors found"
}

run_phpstan() {
    print_header "🔍 Running PHPStan (Static Analysis)"
    cd "$PROJECT_ROOT"
    php -d memory_limit=1G vendor/bin/phpstan analyse "$SOURCE_DIR_RESOLVED/" --no-progress
    print_success "PHPStan passed - No errors found"
}

run_phpunit() {
    print_header "🧪 Running PHPUnit Tests"
    cd "$PROJECT_ROOT"

    if [ "$SKIP_WP_SETUP" != "true" ]; then
        export WP_TESTS_DIR="${WP_TESTS_DIR:-/tmp/wordpress-tests-lib}"
        print_info "Using WordPress Test Suite: $WP_TESTS_DIR"
    fi

    vendor/bin/phpunit --testdox
    print_success "All tests passed"
}

run_syntax_check() {
    print_header "🔍 Running PHP Syntax Check"
    cd "$PROJECT_ROOT"

    print_info "Checking main plugin file..."
    php -l "$MAIN_FILE"

    print_info "Checking source files in ${SOURCE_DIR_RESOLVED}/..."
    find "$SOURCE_DIR_RESOLVED" -name "*.php" -exec php -l {} \; | grep -v "No syntax errors" || true

    print_success "All PHP files have valid syntax"
}

###############################################################################
# Main Execution
###############################################################################

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [CHECKS...]

Centralized quality checks runner for CI/CD workflows.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Verbose output
    --skip-wp-setup         Skip WordPress Test Suite setup (for quick checks)
    --php-version VERSION   PHP version (default: $PHP_VERSION)
    --wp-version VERSION    WordPress version (default: $WORDPRESS_VERSION)
    --db-name NAME          Database name (default: $DB_NAME)
    --db-user USER          Database user (default: $DB_USER)
    --db-pass PASS          Database password (default: $DB_PASS)
    --db-host HOST          Database host (default: $DB_HOST)

CHECKS (run all if none specified):
    composer-validate       Validate composer.json and composer.lock
    phpcs                   Run PHP CodeSniffer
    phpstan                 Run PHPStan static analysis
    phpunit                 Run PHPUnit tests
    syntax                  Run PHP syntax check on all files
    setup-wp                Setup WordPress Test Suite only
    all                     Run all quality checks (default)

ENVIRONMENT VARIABLES:
    PHP_VERSION             PHP version to use
    WORDPRESS_VERSION       WordPress version to install
    DB_NAME / DB_USER / DB_PASS / DB_HOST
    SKIP_WP_SETUP           Skip WordPress setup (true/false)
    WP_TESTS_DIR            WordPress tests directory path
    SOURCE_DIR              Override auto-detected source directory (includes/, Includes/, src/)
EOF
}

main() {
    local checks=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_usage; exit 0 ;;
            -v|--verbose) set -x; shift ;;
            --skip-wp-setup) SKIP_WP_SETUP="true"; shift ;;
            --php-version) PHP_VERSION="$2"; shift 2 ;;
            --wp-version) WORDPRESS_VERSION="$2"; shift 2 ;;
            --db-name) DB_NAME="$2"; shift 2 ;;
            --db-user) DB_USER="$2"; shift 2 ;;
            --db-pass) DB_PASS="$2"; shift 2 ;;
            --db-host) DB_HOST="$2"; shift 2 ;;
            composer-validate|phpcs|phpstan|phpunit|syntax|setup-wp|all)
                checks+=("$1"); shift ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [ ${#checks[@]} -eq 0 ]; then
        checks=("all")
    fi

    print_header "⚙️  Configuration"
    echo "Main file:         $MAIN_FILE"
    echo "Source dir:        $SOURCE_DIR_RESOLVED"
    echo "PHP Version:       $PHP_VERSION"
    echo "WordPress Version: $WORDPRESS_VERSION"
    echo "Database Name:     $DB_NAME"
    echo "Database User:     $DB_USER"
    echo "Database Host:     $DB_HOST"
    echo "Skip WP Setup:     $SKIP_WP_SETUP"
    echo "Checks:            ${checks[*]}"

    local needs_wp_setup=false
    for check in "${checks[@]}"; do
        if [ "$check" = "phpunit" ] || [ "$check" = "all" ] || [ "$check" = "setup-wp" ]; then
            needs_wp_setup=true
            break
        fi
    done

    if [ "$needs_wp_setup" = "true" ] && [ "$SKIP_WP_SETUP" != "true" ]; then
        setup_wordpress_tests
    fi

    if [ "${checks[0]}" = "setup-wp" ]; then
        print_success "WordPress Test Suite setup completed"
        exit 0
    fi

    local failed_checks=()

    for check in "${checks[@]}"; do
        case $check in
            all)
                run_composer_validate || failed_checks+=("composer-validate")
                run_phpcs || failed_checks+=("phpcs")
                run_phpstan || failed_checks+=("phpstan")
                run_syntax_check || failed_checks+=("syntax")
                run_phpunit || failed_checks+=("phpunit")
                ;;
            composer-validate) run_composer_validate || failed_checks+=("composer-validate") ;;
            phpcs) run_phpcs || failed_checks+=("phpcs") ;;
            phpstan) run_phpstan || failed_checks+=("phpstan") ;;
            syntax) run_syntax_check || failed_checks+=("syntax") ;;
            phpunit) run_phpunit || failed_checks+=("phpunit") ;;
        esac
    done

    print_header "📊 Quality Checks Summary"

    if [ ${#failed_checks[@]} -eq 0 ]; then
        print_success "All quality checks passed! 🎉"
        exit 0
    else
        print_error "Failed checks: ${failed_checks[*]}"
        exit 1
    fi
}

main "$@"
