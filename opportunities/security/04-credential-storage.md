# Credential Storage

> **Category:** Security & Privacy
> **Type:** Improvement · **Priority:** High
> **Milestone:** M1 · **Status:** 🔲 Not started

---

## Problem

Atelier needs to store API keys, OAuth tokens for capabilities, and potentially user credentials. These must never be stored in plain text, must survive app restarts, and must be protected against unauthorized access.

## Solution

macOS Keychain for all credentials, with Secure Enclave hardware backing on Apple Silicon.

- **API key:** Stored in Keychain with Secure Enclave protection. Biometric unlock via `LAContext` for first access per session.
- **Capability tokens:** Each capability's OAuth tokens isolated via Keychain Access Groups. Auto-refresh before expiration.
- **Biometric gating:** Sensitive capabilities (ones that can send data externally) require Touch ID before first use per session.

## Status

| Feature | Status |
|---------|--------|
| API key in Keychain with Secure Enclave | 🔲 Not started |
| Capability OAuth token storage | 🔲 Not started |
| Biometric gating for sensitive capabilities | 🔲 Not started |

---

*Back to [Index](../../INDEX.md)*
