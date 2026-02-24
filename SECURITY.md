# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ Yes    |
| < 1.0   | ❌ No     |

Only the latest patch release of each supported minor version receives
security updates.

---

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please report security concerns privately:

1. **Email**: Send a detailed report to the maintainers via the contact
   information listed on the [pub.dev package page](https://pub.dev/packages/davianspace_dependencyinjection).
2. **GitHub Private Reporting**: Use GitHub's
   [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
   feature on this repository (if enabled).

### What to Include

- Description of the vulnerability.
- Steps to reproduce.
- Potential impact assessment.
- Suggested fix (if any).
- Your contact information for follow-up.

### Response Timeline

| Action | Timeline |
|--------|----------|
| Acknowledgement | Within 48 hours |
| Initial assessment | Within 5 business days |
| Fix release | Depends on severity |

---

## Security Considerations

`davianspace_dependencyinjection` is a dependency injection container with the
following security properties:

### No Network Access
This package does not make any network calls. All operations are in-process.

### No Deserialization
Service instances are created via registered factories or constructors — no
arbitrary deserialization or dynamic code loading occurs.

### Disposal Safety
- `DisposalTracker.track()` throws a `StateError` (not just an `assert`) if
  called after disposal, ensuring production code fails fast.
- Scoped providers throw `StateError` on all resolution calls after disposal,
  preventing use-after-free patterns.

### Circular Dependency Detection
The container detects circular dependencies at both build time (via
`DependencyGraph`) and runtime (via `ResolutionChain`), preventing infinite
recursion that could cause stack overflows.

### Factory Isolation
Service factory lambdas receive a `ServiceProviderBase` (not the concrete
`ServiceProvider`), limiting the API surface available inside factories to the
minimum necessary for resolution.

---

## Threat Model

| Threat | Mitigation |
|---|---|
| Infinite recursion via circular deps | Compile-time graph check + runtime chain guard |
| Use-after-dispose | `StateError` thrown on all post-dispose calls |
| Captive dependency (scoped-in-singleton) | `CallSiteValidator` in development mode |
| Unintended service override | `tryAdd*` APIs leave existing registrations intact |
