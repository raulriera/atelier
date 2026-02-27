# Credential Storage

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** 🟠 High

---

## Current State (Electron / Cowork)

MCP connector tokens stored in Electron's local storage or config files. These are effectively plaintext JSON files on disk — accessible to any process running as the same user. No hardware-backed encryption, no access control beyond filesystem permissions.

## Native macOS Approach

macOS **Keychain Services** (`SecItemAdd`/`SecItemCopyMatching`) for all API keys, OAuth tokens, and connector credentials. Hardware-backed encryption via **Secure Enclave** on Apple Silicon.

### Implementation Strategy

- **Keychain storage:** All sensitive credentials (API keys, OAuth tokens, MCP connector secrets) stored in the user's login keychain via `Security.framework`. Encrypted at rest, locked when the user logs out.
- **Access groups:** Use Keychain Access Groups to isolate credentials per MCP connector — the Google Drive connector can't access the Salesforce connector's tokens.
- **Secure Enclave:** For the master Anthropic API key, use `kSecAttrTokenIDSecureEnclave` to store the key in hardware. The key never leaves the Secure Enclave — cryptographic operations happen on-chip.
- **Biometric unlock:** Require Touch ID to access credentials for high-security connectors (financial services, HR systems) via `SecAccessControl` with `.biometryCurrentSet`.
- **Token rotation:** Automatic OAuth token refresh using keychain-stored refresh tokens. Alert users when tokens are about to expire.

### Key Dependencies

- Security.framework (Keychain Services)
- Secure Enclave APIs (`kSecAttrTokenIDSecureEnclave`)
- `SecAccessControl` for biometric gating

---

*Back to [Index](../../INDEX.md)*
