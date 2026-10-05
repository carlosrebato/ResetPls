# Security roadmap

## CodeQL before public launch

- Keep automated CodeQL security analysis as a pre-launch objective.
- The repository became public on 2026-10-05 with the owner's explicit approval.
- The workflow now has `actions: read` and builds Mac and iOS under CodeQL.
  A complete successful analysis/result upload is the remaining verification.
- Private-repository Code Scanning requires GitHub Team or Enterprise with GitHub Code Security; public repositories can use it free of charge.
- Do not purchase a plan, enable paid features, or make the repository public without the owner's explicit approval.
- Keep the complete analysis and result upload passing on subsequent changes.
- Ordinary CI builds and tests remain independent of CodeQL.

Reference: https://docs.github.com/en/code-security/reference/code-scanning/troubleshoot-analysis-errors/private-repository-enablement
