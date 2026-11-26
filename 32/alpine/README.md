# Bitcoin Core 32.1 Alpine candidate

This is an unvalidated source-build candidate, not a published image.
Like Alpine 28, the entrypoint starts as root and switches Bitcoin commands to
the `bitcoin` user, defaulting to UID 100 and GID 101. Runtime `UID` and `GID`
overrides modify that account. Do not override the container user: the
entrypoint requires root for account and directory setup. For `bitcoind`,
it applies umask `077`, sets the data directory to mode `0700`, and changes
ownership of the home and data directories themselves, not their contents.
It forces `bitcoind` to stay in the foreground and print logs to the container
console. Other commands run as root. Mount ACLs and existing files must still
allow the `bitcoin` user access; permission changes can fail on DSM. Do not
mount existing node or wallet data: runtime, wallet migration, rollback and
Synology compatibility have not yet been verified.

The source archive is checked against Bitcoin Core's signed SHA256SUMS using
a pinned snapshot of the upstream builder keys. The signer-key provenance
and signature policy still require independent review. The Alpine image tag
and package repositories are not digest- or snapshot-pinned; reproducibility
and dependency provenance also remain open.

The build workflow requests `linux/amd64`, `linux/arm64` and `linux/arm/v7`
builds of this candidate on pull requests, pushes to `master` or `main`,
and matching tags. These targets are not yet qualified: each requires a
successful build and runtime tests. Matching tags can publish the candidate;
pushes to `master` or `main` can also move the floating `alpine` tag when
registry authentication succeeds. Publication requires the checks below
and a review of tag policy.

## Signature verification and comparison

The Dockerfile imports builder keys from a
[pinned `guix.sigs` commit](https://github.com/bitcoin-core/guix.sigs/tree/93aacee89333de43a96e7d128baa84e737c41b0b/builder-keys).
It requires a successful GPG verification, rejects signature-error statuses,
and checks the source archive against the signed SHA256SUMS. With the default
empty `TRUSTED_BUILDER_FPRS`, it requires at least five distinct primary
`VALIDSIG` fingerprints. A non-empty trusted list requires three distinct
matching fingerprints; duplicates do not count twice. The snapshot pin does
not independently authenticate the builders or approve a signer trust policy.

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

The source build defaults to two parallel compile jobs to limit memory use on
NAS hardware. Override this with `--build-arg BUILD_JOBS=4` on a host with
more available memory.

### Older Synology kernels without `getrandom`

Linux introduced `getrandom` in 3.17. A Synology host running kernel 3.10.108
returned `ENOSYS` for this syscall during an isolated startup test, followed
by Bitcoin aborting before console logging initialized. Bitcoin Core 32.1
detects `getrandom` at compile time; it does not fall back at runtime when
the host kernel lacks the syscall.

For these hosts, opt into Bitcoin Core's existing `/dev/urandom` entropy
path with `USE_DEV_URANDOM=1`. This sets CMake's `HAVE_GETRANDOM=OFF`; it
does not disable OS entropy or introduce a custom random-number generator.
The default `USE_DEV_URANDOM=0` leaves upstream detection unchanged.
Keep the host's OS entropy pool initialized before using this compatibility
build, especially for wallet operations. This workaround does not establish
general support for older kernels.

From the repository root on the DiskStation:

```sh
docker build --platform linux/amd64 --build-arg USE_DEV_URANDOM=1 \
  -t bitcoin-core:32.1-alpine-synology 32/alpine
docker run --rm bitcoin-core:32.1-alpine-synology \
  -regtest -networkactive=0 -daemon=0 -nosettings -stopafterblockimport
```

The startup check uses disposable data without mounting the production
directory and should exit successfully after initialization. Rebuilding
does not replace an existing container: verify this check on the target NAS
before recreating a container with the new image. The compatibility image
has not yet been validated on that host.

### Further qualification

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
