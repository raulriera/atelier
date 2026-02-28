# Credential Storage

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** 🟠 High
> **Milestone:** M1

---

## Problem

Existing tools store credentials in config files or Electron's local storage — effectively plaintext JSON on disk, accessible to any process running as the same user. No hardware-backed encryption, no access control beyond filesystem permissions.

## Solution

macOS **Keychain Services** (`SecItemAdd`/`SecItemCopyMatching`) for all credentials. Hardware-backed encryption via **Secure Enclave** on Apple Silicon.

### What gets stored

| Credential | Storage | Access |
|-----------|---------|--------|
| Anthropic API key | Keychain (Secure Enclave) | App only, biometric optional |
| Capability OAuth tokens (Google Calendar, etc.) | Keychain, per-capability access groups | Isolated per capability |
| Capability secrets (custom MCP servers) | Keychain | App only |

### Implementation Strategy

- **Keychain storage:** All credentials stored in the user's login keychain via `Security.framework`. Encrypted at rest, locked when the user logs out.
- **Access groups:** Use Keychain Access Groups to isolate credentials per capability — the Google Calendar capability can't access the email capability's tokens.
- **Secure Enclave:** For the Anthropic API key, use `kSecAttrTokenIDSecureEnclave` to store the key in hardware. The key never leaves the Secure Enclave — cryptographic operations happen on-chip.
- **Biometric unlock:** Optional Touch ID to access credentials for sensitive capabilities (financial services, HR systems) via `SecAccessControl` with `.biometryCurrentSet`.
- **Token rotation:** Automatic OAuth token refresh using keychain-stored refresh tokens. Alert users when tokens are about to expire.

## Implementation

### Phase 1 — API Key Storage

- Store the Anthropic API key in Keychain on first entry
- Retrieve on app launch to authenticate API calls
- Secure Enclave for hardware-backed protection on Apple Silicon

### Phase 2 — Capability Credentials

- Per-capability Keychain access groups
- OAuth token storage and automatic refresh for capabilities that need authentication
- Credential lifecycle: store on capability activation, clear on disconnection

### Phase 3 — Biometric Gating

- Optional Touch ID requirement for accessing sensitive capability credentials
- `SecAccessControl` with `.biometryCurrentSet`
- Configurable per capability in project settings

## Dependencies

- architecture/01-application-shell.md (API key storage is part of M0 first-launch flow)
- hub/03-plugin-management.md (capability OAuth tokens)

## Notes

Credentials are the most sensitive data Atelier handles. The Keychain is the only acceptable storage location — never UserDefaults, never files, never environment variables. The Secure Enclave integration for the API key is not optional — it's the baseline.

---

*Back to [Index](../../INDEX.md)*
