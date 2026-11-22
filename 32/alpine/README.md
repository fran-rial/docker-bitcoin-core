# Bitcoin Core 32.1 Alpine candidate

This is an unvalidated source-build candidate, not a published image.
It defaults to UID 100 and GID 101 and starts as the non-root `bitcoin` user.
The entrypoint does not change ownership or apply runtime UID/GID overrides;
mounted data directories must already be accessible and owned by the user
running the container so their permissions can be set to `0700`. Startup
fails if the data directory cannot be created or its permissions cannot be
set. Do not mount existing node or wallet data: build, runtime, wallet
migration, rollback and Synology compatibility have not yet been verified.

The source archive is checked against Bitcoin Core's signed SHA256SUMS using
a pinned snapshot of the upstream builder keys. The signer-key provenance
and signature policy still require independent review. The Alpine image tag
and package repositories are not digest- or snapshot-pinned; reproducibility
and dependency provenance also remain open.

The build workflow requests `linux/amd64`, `linux/arm64` and `linux/arm/v7`
builds of this candidate on pull requests only. These targets are not yet
qualified: each requires a successful build and runtime tests. The workflow
does not publish `32.1-alpine` or move the floating `alpine` tag; enabling
releases requires the checks below and a separate review of the tag policy.

## Signature verification and comparison

The Dockerfile imports builder keys from a
[pinned `guix.sigs` commit](https://github.com/bitcoin-core/guix.sigs/tree/93aacee89333de43a96e7d128baa84e737c41b0b/builder-keys).
It requires a successful GPG verification, rejects signature-error statuses,
and checks the source archive against the signed SHA256SUMS. With the default
empty `TRUSTED_BUILDER_FPRS`, it requires at least five distinct primary
`VALIDSIG` fingerprints. The alternative non-empty trusted-list branch is
unsafe: repeated entries for one fingerprint can satisfy its three-signer
threshold. Do not use that branch until it counts distinct trusted signers.
The snapshot pin does not independently authenticate the builders or approve
a signer trust policy.

For comparison, the [NixOS Bitcoin package](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bi/bitcoin/package.nix)
checks specific fingerprints and pins hashes of its inputs.
[docker-bitcoind](https://github.com/kylemanna/docker-bitcoind/blob/master/Dockerfile)
matches a signature against a configured fingerprint list after keyserver
retrieval. [Core Lightning](https://github.com/ElementsProject/lightning/blob/master/Dockerfile)
imports keys stored in its repository and checks signatures and checksums.
These are different policies, not independent identity proofs for this image.
The comparison reflects the sources inspected on 2026-11-22; their branches
can change.

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

To check each target separately on a Docker Buildx host with native support or
configured QEMU emulation, load one single-platform image at a time:

```sh
(
  set -e
  for platform in linux/amd64 linux/arm64 linux/arm/v7; do
    docker buildx build --platform "$platform" --load \
      -t bitcoin-core:32.1-alpine-candidate 32/alpine
    for executable in bitcoind bitcoin-cli bitcoin-tx; do
      docker run --rm --platform "$platform" --entrypoint "$executable" \
        bitcoin-core:32.1-alpine-candidate -version
    done
  done
)
```

Emulated builds can take substantially longer and need more resources.
Passing these checks does not prove native hardware or Synology compatibility.

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
