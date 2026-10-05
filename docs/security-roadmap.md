# Security roadmap

## CodeQL before public launch

- Keep automated CodeQL security analysis as a pre-launch objective.
- The current private repository does not have GitHub Code Scanning enabled.
- Private-repository Code Scanning requires GitHub Team or Enterprise with GitHub Code Security; public repositories can use it free of charge.
- Do not purchase a plan, enable paid features, or make the repository public without the owner's explicit approval.
- When CodeQL is supported, grant the workflow `actions: read` alongside its existing permissions and verify a complete successful analysis and result upload.
- Ordinary CI builds and tests remain independent of CodeQL.

Reference: https://docs.github.com/en/code-security/reference/code-scanning/troubleshoot-analysis-errors/private-repository-enablement
