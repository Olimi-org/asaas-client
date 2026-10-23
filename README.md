# asaas-client

Generated Rust client for the [Asaas v3 API](https://www.asaas.com/openApi/document?version=3&languageCode=pt-BR)
(Brazilian payments gateway: Pix, boleto, credit card, subscriptions, webhooks).

- `openapi.json` is the vendored upstream spec, committed so regeneration is
  reproducible and Asaas-side changes show up as reviewable diffs.
- `openapi-to-rust.toml` is the generation config.
- `src/generated/` holds the generated output (`types.rs`, `client.rs`, plus
  the tool's `REQUIRED_DEPS.toml` fragment). Overwritten by `regen.sh`; never
  hand-edit.
- `src/lib.rs` re-exports the generated tree flat
  (`asaas_client::PaymentGetResponseDTO`).
- Generator: `openapi-to-rust` 0.22.0, pinned in `regen.sh`; output can
  change across minor versions, so bump it deliberately.

## Regenerate

```sh
./regen.sh
```

Runs the pinned generator, then fails on dependency drift.

## Error model

Every operation returns `Result<T, ApiOpError<OpApiError>>`:

- `Api` variants carry an `ApiError` envelope with status, headers, and the
  raw response body, plus Asaas's `errors: [{code, description}]` list, even
  when typed deserialization failed. Nothing an undocumented response
  carries is ever thrown away.
- `Transport` variants are network/timeout/serialization failures.
- The client caps response bodies at 8 MiB by default and returns a typed
  `ResponseTooLarge` error.

## Auth

Asaas authenticates with an `access_token` header (the account API key).
The generated client deliberately has no credential handling: inject a
pre-configured `reqwest::Client` and keep the key in server config. Never
ship the key in a client-side app. Call Asaas from your server and have
clients call your backend instead.

```rust
use asaas_client::AsaasClient;

let mut headers = reqwest::header::HeaderMap::new();
headers.insert("access_token", api_key.parse()?);
let http = reqwest::Client::builder().default_headers(headers).build()?;
let asaas = AsaasClient::with_client(http).with_base_url("https://api.asaas.com");
```

Note: `HttpClient::with_api_key` sends `Authorization: Bearer …`, not the
Asaas scheme. Use the default-headers injection above.

## Base URLs

`with_client` defaults to the sandbox (`https://api-sandbox.asaas.com`), the
spec's `servers[0]`; set the real base explicitly. The sandbox also exposes
"Ações em sandbox" endpoints (see spec tags) to force payment states
during live probes.
