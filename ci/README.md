# Optional GitHub Actions checks

`checks.yml` defines companion tests and universal app packaging, portable
button-state tests, and a firmware compile with the pinned Arduino profile.

The credentials used for the initial publication lacked GitHub's `workflow`
scope. The workflow is included here as a template; **GitHub Actions is not
enabled by this file**.

To activate it, use an account/token allowed to write workflows and move
`ci/checks.yml` to `.github/workflows/checks.yml`, then commit and push. The same
checks can be run locally using the commands in the component READMEs.
