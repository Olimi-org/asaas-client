#!/usr/bin/env bash
# Regenerates src/generated/ from the committed Asaas OpenAPI spec.
#
# openapi-to-rust consumes the spec as published, with no normalization
# patches and no post-generation sed. The generator is vendored at
# bin/openapi-to-rust, so the binary in the tree is the pin; bump it
# deliberately and review the diff. Size-optimized build (verified
# byte-identical output vs default):
#   CARGO_PROFILE_RELEASE_OPT_LEVEL=s CARGO_PROFILE_RELEASE_PANIC=abort \
#   CARGO_PROFILE_RELEASE_STRIP=symbols CARGO_PROFILE_RELEASE_LTO=fat \
#   CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
#   cargo install openapi-to-rust --version <v> --force --root /tmp/o2r
#   cp /tmp/o2r/bin/openapi-to-rust bin/
#
# Staleness check (CI): `bin/openapi-to-rust generate --config
# openapi-to-rust.toml --check` fails when generated files are missing or
# not up to date with the spec.
#
# To refresh the spec itself, review the diff (Asaas doesn't version the
# doc beyond `version=3`):
#   curl -sL "https://www.asaas.com/openApi/document?version=3&languageCode=pt-BR" -o openapi.json
set -euo pipefail
cd "$(dirname "$0")"

bin/openapi-to-rust generate --config openapi-to-rust.toml

# Cargo.toml is not regenerated; REQUIRED_DEPS.toml is the tool's statement of
# what the generated code needs. Fail on drift so dep changes are merged
# deliberately, not discovered at build time.
expected="bytes chrono futures-util reqwest reqwest-middleware serde serde_json thiserror"
found="$(grep -oE '^[a-z0-9_-]+' src/generated/REQUIRED_DEPS.toml | sort -u)"
if [ "$found" != "$(printf '%s\n' $expected | sort -u)" ]; then
    echo "regen.sh: dependency drift, REQUIRED_DEPS.toml no longer matches Cargo.toml:" >&2
    diff <(printf '%s\n' $expected | sort -u) <(echo "$found") >&2 || true
    exit 1
fi

cargo check -p asaas-client
echo "Regenerated and checked: $(grep -c 'pub async fn' src/generated/client.rs) operations in src/generated/client.rs"
