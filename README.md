# Karkain-Validation

Reusable data and rule validation for the Karkain ecosystem.

- **Language baseline:** Karkain Language v1.2.0 (verified tag `v1.2.0`,
  commit `77d70693e1e3134dac312a303bffafa7d50fa988`).
- **Framework version:** `0.1.0-dev`.
- **Status:** VERIFIED — module, 26 native tests, integration program,
  negative gate and runnable example all executed with the real compiler.
- **Repository model:** independent; no submodules and no framework
  dependencies.

## Purpose

Karkain-Validation applies named rules to values and fields, collects
structured diagnostics, and reports overall success or failure. It is a
data-validation layer, distinct from test execution (Karkain-Testing) and
from compiler type checking.

## Result convention

Top-level structs are unavailable in the verified stable subset. A report
is a flat mixed array of error triples:

```text
[field, rule, message, field, rule, message, ...]
```

An empty report means valid. Arrays are values, so callers capture the
returned report: `report = validation.required(report, "name", name)`.

## Public API

Module: `src/validation.kark` (import as `validation`).

| Group | Functions |
|---|---|
| Report | `new_report`, `add_error`, `expect`, `error_count`, `is_valid`, `error_field`, `error_rule`, `error_message`, `field_error_count`, `merge_reports` |
| Required/empty | `required`, `require_nonzero`, `empty` |
| Numeric | `min_value`, `max_value`, `in_range` |
| Length | `min_length`, `max_length`, `length_range` |
| Formats | `is_digits`, `is_alpha`, `is_alphanumeric`, `is_email_basic`, `format` |
| Custom | `custom_rule`, `custom_rule_message` |
| Multi-field | `validate_required_all`, `validate_range_all` |
| Reporting | `summarize`, `print_report` |

`format` accepts `"digits"`, `"alpha"`, `"alphanumeric"` and `"email"`.
An unknown format name records an `input`-style error instead of being
silently accepted. Custom rules accept an application-computed 1/0 result.

## Layout

```text
src/validation.kark       framework implementation (public API)
src/verify.kark           integration program
tests/api_tests.kark      26 native test_* bodies
examples/user_profile.kark runnable application example
scripts/verify.ps1        verification gate
COMPATIBILITY.md          evidence-based baseline assessment
karkain.toml              project manifest (version 0.1.0-dev)
```

## Verification

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
```

Gates: module `check`; 26 native tests (expected 26/26); integration `run`;
a negative gate proving exit code 4; and a runnable example. Because
`karkain test` cannot resolve imports, the native test program is generated
from the real module source plus the test bodies in a temporary directory.

## Dependencies

None. No framework-to-framework dependency is introduced.

## Known limitations

- `required` targets strings/arrays; use `require_nonzero` for numbers
  because `len(number)` is `0` in v1.2.0.
- `is_email_basic` is a simple structural check, not full RFC validation.
- Custom rules take a predicate result; function pointers are not used.
- No cross-platform or heterogeneous-target support is claimed. See
  `COMPATIBILITY.md`.
