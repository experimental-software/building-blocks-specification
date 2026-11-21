# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

[Semantic Versioning](https://semver.org/spec/v2.0.0.html) is not used, yet. This is the intended meaning of the version number parts:

- Major version: 0, to indicate that the project is experimental.
- Minor version: Gets incremented with each breaking change.
- Path version: Gets incremented with each non-breaking structural change.

## [Unreleased]

### Added

- Optional `features` property on all components for Gherkin features (with rules, backgrounds, scenarios and tags without the leading `@`; steps are plain strings, multi-line for doc strings, and data tables; an examples table is a separate last step).
- Optional string label property for input components.
- Optional clearIcon boolean property for input components, defaulting to false.

## [0.1.6] - 2026-11-15

### Added

- Optional readonly and required boolean properties for input components.
- SplitButton view component with persistent selection and labeled options.

## [0.1.5] - 2026-11-07

### Added

- Optional string id property for components.

## [0.1.4] - 2026-11-07

### Added

- Optional input properties for currency formatting and numeric bounds.

## [0.1.3] - 2026-11-07

### Changed

- Added editor help text for schema properties.

## [0.1.2] - 2026-11-01

### Changed

- Added an optional description property to components.

## [0.1.1] - 2026-10-31

### Changed

- Component `type` is required and accepts any string value.
