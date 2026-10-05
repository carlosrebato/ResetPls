# Security roadmap

## CodeQL before public launch

- Keep automated CodeQL security analysis as a pre-launch objective.
- The repository became public on 2026-10-05 with the owner's explicit approval.
- The workflow now has `actions: read` and builds Mac and iOS under CodeQL.
  The first public dual-platform analysis uploaded successfully on 2026-10-05
  (analysis 1893045280, commit `a6b1660`), with zero results and no analysis error.
  The job reached its old 30-minute timeout during final cleanup; its budget is
  now 60 minutes so subsequent runs can complete their post-job steps too.
- Private-repository Code Scanning requires GitHub Team or Enterprise with GitHub Code Security; public repositories can use it free of charge.
- Do not purchase a plan, enable paid features, or make the repository public without the owner's explicit approval.
- Keep the complete analysis and result upload passing on subsequent changes.
- Ordinary CI builds and tests remain independent of CodeQL.

Reference: https://docs.github.com/en/code-security/reference/code-scanning/troubleshoot-analysis-errors/private-repository-enablement
