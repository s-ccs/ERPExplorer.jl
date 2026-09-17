# Changelog

## 0.2.0 — unreleased

### Added

- JLD2 model loading and a data-source launcher, including standard Unfold saves,
  nested model selection, and CSV/TSV channel-label mappings.
- A **Change dataset** button in the launcher, with loading options preserved on return
  and after failed loads.
- Event selection, numeric channel selection without a montage, and topographic time series.
- Independent line/marker layers, expanded categorical styles and precise slider controls.
- Regression tests for saved-model predictions, channel identity, shared event schemas,
  time-bin options, production dashboard updates, and browser interaction.

### Fixed

- Reconstruct omitted design matrices before computing effects from saved models.
- Make discovered nested model keys usable for explicit model selection.
- Preserve slider precision and reject channel mappings that would change channel identity.
- Merge continuous bounds across formulas and reject incompatible shared categorical/spline schemas.
- Honor explicit bin widths and reject conflicting or invalid time-bin options.
- Scope CSS and sizing to the embedding container; keep small layouts scrollable.
- Preserve configured axis limits when rendering and resetting plots.
- Serialize ERP and topographic-series builds so first-use compilation cannot overlap
  their browser acknowledgement waits.
- Make benchmark failures fail the process; run package and production browser tests in CI.

### Changed

- Channel/event changes reuse effects; the live benchmark uses the production dashboard.
- Topoplot series starts collapsed, reuses unchanged figures and caps rendering at 60
  topoplots by default (configurable). Interactive maps use a configurable 128×128
  interpolation grid to bound rendering work.
- Julia 1.11 is the minimum supported version. CSV/JLD2 test-extra duplication removed.
