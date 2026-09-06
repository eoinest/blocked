# GitHub CLI

Blocked bundles GitHub CLI 2.100.0, copyright GitHub Inc., under the MIT
license reproduced in `GitHubCLI-LICENSE.txt`.

- Source: https://github.com/cli/cli/tree/v2.100.0
- Official release: https://github.com/cli/cli/releases/tag/v2.100.0
- Upstream checksums: https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_checksums.txt

The build downloads the official macOS arm64 and amd64 ZIP archives, verifies
their pinned SHA256 values before extraction, and combines their executables
with Apple's `lipo`. The resulting universal helper is at `Contents/MacOS/gh`.
It is signed with the app's selected identity. No GitHub account or credentials
are included in the bundle.

## Building without network access

Run `companion/scripts/build-app.sh --offline` after an initial build to reuse
the verified archives in `companion/.build/gh-downloads`. To use a separately
prepared cache, set `GH_ARCHIVE_DIR` to a directory containing both ZIPs named
exactly as listed in `companion/scripts/gh-checksums.sha256`. Checksums are always
verified, including offline builds. Missing or altered archives fail the build.

For development with an existing local GitHub CLI installation, use
`companion/scripts/build-app.sh --without-gh`. This omits the bundled helper;
do not distribute that build as a self-contained installation.

Default signing is ad-hoc for local testing. Distribution requires a Developer
ID certificate selected with `SIGNING_IDENTITY`, notarization, and stapling;
this script does not submit builds to Apple or publish releases.

## Updating

Update the version in `bundle-gh.sh`, both entries in `gh-checksums.sha256`, this
notice, and the license together. Obtain checksums from the same official
release and compare them with the GitHub release API's asset digests. Verify
both binary architectures, minimum macOS versions, execution of `gh --version`,
and the complete app signature before distributing the updated app.
