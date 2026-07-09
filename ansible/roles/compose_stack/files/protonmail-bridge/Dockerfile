# issue 029 — patched Proton Mail Bridge image.
#
# The upstream shenxn `deb` image (base debian:sid-slim) is a REPACK of Proton's
# bridge .deb with dependencies deliberately stripped, and it bundles bridge v3.19.0.
# At runtime the bridge AUTO-UPDATES itself to the latest release (currently v3.25.0),
# which links against libfido2 (FIDO2 / hardware-key support, added ~v3.20). That
# library was stripped by the repack, so the self-updated binary dies at launch with:
#   error while loading shared libraries: libfido2.so.1: cannot open shared object file
#
# Add libfido2 back so the updated bridge launches. Everything else — socat port
# forwarding, pass/gpg keyring, libsecret, the entrypoint — is inherited unchanged.
# (libsecret-1-0 is already installed in the base image.)
FROM shenxn/protonmail-bridge:3.19.0-1

RUN apt-get update \
    && apt-get install -y --no-install-recommends libfido2-1 \
    && rm -rf /var/lib/apt/lists/*
