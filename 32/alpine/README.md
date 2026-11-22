# Bitcoin Core 32.1 Alpine candidate

This is an unvalidated source-build candidate, not a published image.
It preserves the Alpine image's UID/GID defaults and entrypoint conventions,
including recursive ownership changes. Do not mount existing node or wallet
data: build, runtime, wallet migration, rollback and Synology compatibility
have not yet been verified.

The source archive is checked against Bitcoin Core's signed SHA256SUMS using
a pinned snapshot of the upstream builder keys. The signer-key provenance
and signature policy still require independent review. The Alpine image tag
and package repositories are not digest- or snapshot-pinned; reproducibility
and dependency provenance also remain open.

## Isolated build and smoke checks

On a Docker-capable Linux or WSL host, from the repository root:

```sh
docker build --platform linux/amd64 -t bitcoin-core:32.1-alpine-candidate 32/alpine
docker run --rm --entrypoint bitcoind bitcoin-core:32.1-alpine-candidate -version
docker run --rm --entrypoint bitcoin-cli bitcoin-core:32.1-alpine-candidate -version
docker run --rm --entrypoint bitcoin-tx bitcoin-core:32.1-alpine-candidate -version
```

These are only build and executable smoke checks. Before publication or live
use, test signature failures, runtime dependencies, isolated regtest RPC,
block-filter scanning, persistence, shutdown, user IDs and synthetic wallet
migration. Review CI tag behavior and test on the target DSM/kernel separately.
Never use an existing production data directory for these tests.

## GitHub CLI on macOS and WSL

On macOS, if GitHub CLI was installed with the existing Spack installation:

```sh
. ~/dev/spack/share/spack/setup-env.sh
spack load gh
gh --version
```

WSL has a separate environment. Follow the
[official Linux installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md),
then check `gh --version`. Authenticate interactively with `gh auth login`;
do not copy credentials into commands or share tokens. Keep WSL private state
on its Linux filesystem rather than `/mnt/c`.
