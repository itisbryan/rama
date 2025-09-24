# CI/CD Setup for Rama

This document describes the Continuous Integration and Continuous Deployment setup for the Rama project.

## Overview

The CI/CD pipeline includes:
- ✅ **Code Quality**: RuboCop linting with Rails and RSpec extensions
- ✅ **Security Scanning**: Brakeman and bundle-audit
- ✅ **Testing**: Comprehensive test suite across multiple Ruby/Rails versions
- ✅ **Multi-Database Support**: PostgreSQL, MySQL, SQLite3
- ✅ **Coverage Reporting**: SimpleCov with Codecov integration
- ✅ **Automated Releases**: Gem publishing to RubyGems
- ✅ **Demo Application**: Automated demo app testing

## GitHub Actions Workflows

### 1. Main CI Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**Jobs:**

#### RuboCop Linting
- Runs RuboCop with parallel processing
- Enforces code style and quality standards
- Includes Rails, RSpec, and Performance cops

#### Test Matrix
- **Ruby versions**: 3.1, 3.2, 3.3
- **Rails versions**: 7.1, 8.0
- **Databases**: PostgreSQL, MySQL, SQLite3
- **Excludes**: Some combinations to optimize CI time

#### Security Scanning
- **Brakeman**: Static security analysis
- **Bundle Audit**: Dependency vulnerability scanning

#### Build Verification
- Gem building and artifact upload
- Demo application creation and testing

### 2. Release Pipeline (`.github/workflows/release.yml`)

**Triggers:**
- Git tags matching `v*` pattern (e.g., `v1.0.0`)

**Process:**
1. Run full test suite
2. Run quality checks (RuboCop, security)
3. Build gem
4. Publish to RubyGems
5. Create GitHub release with artifacts

## RuboCop Configuration

### Main Configuration (`.rubocop.yml`)

```yaml
# Key settings
AllCops:
  TargetRubyVersion: 3.1
  TargetRailsVersion: 7.1
  NewCops: enable

# Enabled cops
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

# Customizations for DSL
Layout/LineLength:
  Max: 120

Style/Documentation:
  Enabled: false  # DSL classes don't need docs

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - 'examples/**/*'
    - 'lib/rama/dsl_configs.rb'
```

### TODO Configuration (`.rubocop_todo.yml`)

Contains temporary exclusions for existing code that needs refactoring.

## Local Development

### Running Quality Checks

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -A

# Run security checks
bundle exec brakeman
bundle exec bundle-audit update && bundle exec bundle-audit

# Run all quality checks
rake quality:all

# Run full CI suite locally
rake ci:all
```

### Pre-commit Hooks

Install pre-commit hooks to catch issues early:

```bash
# Install pre-commit (requires Python)
pip install pre-commit

# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

**Hooks included:**
- Trailing whitespace removal
- End-of-file fixing
- YAML/JSON validation
- RuboCop linting
- RSpec tests (on push)
- Brakeman security scan (on push)

## Database Setup for CI

### PostgreSQL
```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: rama_test
```

### MySQL
```yaml
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: rama_test
```

### SQLite3
No service required - uses file-based database.

## Environment Variables

### Required for CI
- `DATABASE_URL`: Database connection string
- `DB_ADAPTER`: Database adapter (postgresql, mysql2, sqlite3)
- `RAILS_VERSION`: Rails version for testing
- `RAILS_ENV`: Set to `test`

### Required for Release
- `RUBYGEMS_API_KEY`: RubyGems API key for publishing
- `GITHUB_TOKEN`: GitHub token for releases (auto-provided)

## Coverage Reporting

### SimpleCov Configuration
```ruby
# In spec_helper.rb
if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-lcov'

  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = 'coverage/lcov/rama.lcov'
  end

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]

  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/examples/'
    add_filter '/vendor/'
    add_filter '/bin/'

    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Components', 'app/components'
    add_group 'Jobs', 'app/jobs'
    add_group 'Libraries', 'lib'
  end
end
```

### Codecov Integration
- Uses GitHub Action for coverage upload (codecov/codecov-action@v4)
- Generates LCOV format for better compatibility
- Provides coverage badges and PR comments
- Tracks coverage trends over time
- No gem dependency conflicts

## Performance Testing

Performance tests run only on:
- Ruby 3.2
- Rails 8.0
- PostgreSQL

This reduces CI time while ensuring performance regressions are caught.

## Demo Application Testing

For pull requests, the CI:
1. Creates a demo Rails application
2. Installs Rama gem
3. Sets up sample data
4. Starts the server
5. Tests basic functionality with curl

## Troubleshooting CI Issues

### Common Problems

**RuboCop Failures:**
```bash
# Fix locally
bundle exec rubocop -A
git add . && git commit -m "Fix RuboCop issues"
```

**Test Failures:**
```bash
# Run specific test
bundle exec rspec spec/path/to/failing_spec.rb:line_number

# Run with verbose output
bundle exec rspec --format documentation
```

**Database Issues:**
```bash
# Reset test database
cd spec/dummy
bundle exec rails db:drop db:create db:migrate RAILS_ENV=test
```

**Dependency Issues:**
```bash
# Update bundle
bundle update

# Check for security issues
bundle exec bundle-audit update && bundle exec bundle-audit
```

### CI Matrix Failures

If specific Ruby/Rails/Database combinations fail:

1. Check the CI logs for specific errors
2. Test locally with the same combination
3. Update exclusions in `.github/workflows/ci.yml` if needed
4. Consider if the combination is supported

## Release Process

### Manual Release

1. Update version in `lib/rama/version.rb`
2. Update `CHANGELOG.md`
3. Commit changes: `git commit -m "Bump version to X.Y.Z"`
4. Create tag: `git tag vX.Y.Z`
5. Push: `git push origin main --tags`

### Automated Release

The release workflow will:
1. Run all tests and quality checks
2. Build the gem
3. Publish to RubyGems
4. Create GitHub release with notes

## Monitoring

### GitHub Actions
- Monitor workflow runs in the Actions tab
- Set up notifications for failed builds
- Review performance trends

### RubyGems
- Monitor gem downloads and usage
- Check for security advisories

### Codecov
- Track coverage trends
- Set coverage thresholds
- Monitor PR coverage changes

## Security

### Dependency Scanning
- `bundle-audit` checks for known vulnerabilities
- Runs on every CI build
- Automatically updates vulnerability database

### Static Analysis
- `brakeman` scans for security issues
- Configured to fail CI on warnings
- Covers Rails-specific security patterns

### Secrets Management
- Use GitHub Secrets for sensitive data
- Never commit API keys or passwords
- Rotate secrets regularly

This CI/CD setup ensures high code quality, security, and reliability for the Rama project while providing fast feedback to developers.
