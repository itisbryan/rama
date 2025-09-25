# Changelog

## [Unreleased]

### Added
- New `rama:resources:scaffolds` generator that automatically creates Rama resources for existing models
  - Detects and configures boolean fields as toggle filters
  - Detects and configures enums as select filters
  - Detects and configures scopes as filterable options
  - Configures search for all searchable fields
  - Generates basic CRUD actions
  - Supports `--skip`, `--only`, and `--force` options
- New Rake task `generate:resources` for programmatic generation
- Comprehensive documentation in `docs/resource_scaffolding.md`

### Changed
- Updated README with quick start instructions for the new generator
- Added development dependencies for generator testing

### Fixed
- Fixed lint warnings in generator code
