#!/usr/bin/env bash
set -x
mkdir -p /var/tmp/ci/cargo-home
docker run --rm --security-opt seccomp=unconfined \
  -v /var/tmp/ci/lumin:/workspace/lumin -v /var/tmp/ci/cargo-home:/cargo \
  -w /workspace/lumin -e CARGO_HOME=/cargo -e DEBIAN_FRONTEND=noninteractive \
  -e CARGO_TERM_COLOR=never \
  debian:trixie bash -lc '
set -e
apt-get -qq update >/dev/null
apt-get -qq install -y valgrind build-essential curl ca-certificates pkg-config >/dev/null
curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none --profile minimal --no-modify-path >/dev/null
export PATH=/cargo/bin:$PATH
rustup toolchain install 1.94.1 --profile minimal >/dev/null 2>&1 || true
rustc --version; valgrind --version; ldd --version | head -1
command -v gungraun-runner >/dev/null || cargo install gungraun-runner --version 0.19.4 >/dev/null
gungraun-runner --version
echo "=== M4: perf gate ==="
env -u LUMIN_PERF_BLESS cargo bench -p lumin --bench perf 2>&1 | tail -200
'
echo "WRAPPER_EXIT=$?"
