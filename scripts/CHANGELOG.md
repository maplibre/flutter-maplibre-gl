## 0.23.0 (Scripts / Code Generation)

Internal tooling package used for code generation and maintenance tasks in the mono‑repo. Not published to pub.dev.

### Context
This snapshot reflects the tooling state used to generate bindings for the 0.23.0 release of `maplibre_gl`. 

### Changes
* Minor adjustments to `generate.dart` and templates to fix iOS Offset / Translate / expression array handling.
* Repository housekeeping & lint alignment.

### When to bump
If you introduce a new flag, template placeholder, or change the output shape, increment the version here to keep reproducibility for past releases.
