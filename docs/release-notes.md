# Taq Module Release Notes

_This document provides the version history of the KDB-X Taq Module, detailing released versions, fixes, and improvements._

## Unreleased

### Fixes and Improvements

- New `parseToDisk` option `sortbytime` produces time-sorted (`` `s#time``) output via bounded-memory per-batch staging and a k-way merge, enabling CE-friendly ingest of datasets that exceed the working-set cap.

## 1.1.0

**Release Date**: 2026-03-19

### Fixes and Improvements

- New function (`parseToMemory`) to parse data into memory.
- New `parseToDisk` option `linked` to create linked columns to master.
- **NUC**: Values of `exnames` are now strings instead of symbols.
- **NUC**: `compparam` requires table-specific compression parameters.

## 1.0.1

**Release Date**: 2026-03-12

### Fixes and Improvements

- Quote column name fix: `Bsize` -> `bsize`.
- Improved input parameter validation.
- Documentation fixes.

## 1.0.0

**Release Date**: 2026-03-02

The Taq module is designed for benchmarking and is based on the [KX Taq scripts](https://github.com/KxSystems/kdb-taq). Key differences compared to [taq.k](https://github.com/KxSystems/kdb-taq/blob/master/taq.k) include:

- Rewritten code from k to q.
- Destination directory is now configurable.
- Added support for compression.
- Introduced a new parameter to filter by the first letter of the Symbol.
- Enhanced error handling.
- Improved code quality.
- Added an option to drop test symbols.
- Columns are written in parallel for better performance.
- Batch processing support for a smaller memory footprint.
- Function documentation now uses qdoc syntax.
