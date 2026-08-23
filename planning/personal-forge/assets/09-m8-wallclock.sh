#!/usr/bin/env bash
set -x
docker run --rm --security-opt seccomp=unconfined \
  -v /var/tmp/ci/lumin:/workspace/lumin -v /var/tmp/ci/cargo-home:/cargo \
  -w /workspace/lumin -e CARGO_HOME=/cargo -e CARGO_TERM_COLOR=never \
  -e DEBIAN_FRONTEND=noninteractive debian:trixie bash -lc '
set -e
apt-get -qq update >/dev/null
apt-get -qq install -y build-essential curl ca-certificates pkg-config >/dev/null
export PATH=/cargo/bin:$PATH
echo "=== M8: particles wall-clock (v0.1 bar) ==="
cargo test -p particles --release -- --ignored --nocapture 2>&1 | tail -40
'
echo "WRAPPER_EXIT=$?"
