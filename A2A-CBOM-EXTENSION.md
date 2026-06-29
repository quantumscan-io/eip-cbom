# A2A Extension: CBOM Capability Declaration

**Extension key:** `quantumscan.io/cbom`  
**Status:** Draft  
**A2A spec version:** 1.0 (Linux Foundation)  
**Companion standard:** EIP-7789 (Cryptographic Bill of Materials on-chain)

---

## Motivation

The A2A Protocol ([a2a-protocol.org](https://a2a-protocol.org)) defines an `extensions` field in the AgentCard that allows agents to declare capabilities beyond the base spec. This document proposes a standard extension key — `quantumscan.io/cbom` — that any agent can add to its AgentCard to signal that it produces or consumes **Cryptographic Bill of Materials (CBOM)** output.

Without a shared extension schema, an A2A orchestrator has no machine-readable way to:

1. Discover which agents can supply CBOM artifacts
2. Route CBOM artifacts to downstream agents (compliance reporters, risk aggregators, on-chain registries)
3. Verify that CBOM output conforms to a specific standard (CycloneDX CBOM 1.6, EIP-7789, etc.)

---

## Extension Schema

The following JSON object is placed under the `extensions` key in an AgentCard:

```json
{
  "extensions": {
    "quantumscan.io/cbom": {
      "cbomStandard": "EIP-7789",
      "cbomVersion": "1.0.0",
      "supportedOutputFormats": ["eip-7789-json", "cyclonedx-cbom-1.6"],
      "quantumRiskScoreRange": [0, 100],
      "cbomSchemaUrl": "https://quantumscan.io/schemas/cbom-eip7789-v1.json",
      "algorithmRegistryUrl": "https://github.com/quantumscan-io/eip-cbom"
    }
  }
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `cbomStandard` | string | yes | Primary standard. Values: `"EIP-7789"`, `"CycloneDX-1.6"`, `"SPDX-3.0"` |
| `cbomVersion` | string | yes | Version of the CBOM schema the agent implements |
| `supportedOutputFormats` | string[] | yes | List of formats the agent can emit. Known values: `"eip-7789-json"`, `"cyclonedx-cbom-1.6"` |
| `quantumRiskScoreRange` | [number, number] | no | `[min, max]` range of the quantum risk score returned in artifacts |
| `cbomSchemaUrl` | string | no | URL to the JSON Schema for the CBOM artifact |
| `algorithmRegistryUrl` | string | no | URL to the algorithm registry used for algorithm IDs |

---

## CBOM Artifact in A2A Tasks

When an agent with this extension returns a completed task (`tasks/get`), it SHOULD include at least one artifact with `mimeType: "application/json"` containing a CBOM manifest:

```json
{
  "id": "3f2a1b...",
  "status": { "state": "completed", "timestamp": "2026-06-29T12:00:00Z" },
  "artifacts": [
    {
      "name": "cbom-eip7789",
      "mimeType": "application/json",
      "parts": [
        {
          "type": "data",
          "data": {
            "$schema": "https://quantumscan.io/schemas/cbom-eip7789-v1.json",
            "cbomVersion": "1.0.0",
            "generatedAt": "2026-06-29T12:00:00Z",
            "generatedBy": "agent-name v1.0.0",
            "repoUrl": "https://github.com/example/myapp",
            "scanId": "3f2a1b...",
            "quantumRiskScore": 72,
            "primitives": [
              {
                "id": "detected-ecdsa",
                "type": "SIGNATURE",
                "algorithm": "ECDSA",
                "keyBits": 256,
                "purpose": "signature verification",
                "quantumStatus": "VULNERABLE",
                "migrationTarget": "ML-DSA-65 (NIST FIPS 204)",
                "detectedInFiles": ["src/auth/jwt.ts"],
                "eipReference": null
              }
            ],
            "hndlExposedCount": 1
          }
        }
      ]
    }
  ]
}
```

---

## Reference Implementation

`QuantumScan` implements this extension at:

- **AgentCard:** `https://quantumscan.io/.well-known/agent.json`
- **A2A endpoint:** `https://quantumscan.io/api/a2a`
- **Methods supported:** `tasks/send`, `tasks/get`, `tasks/cancel`

### tasks/send

Send a repository URL in the message text:

```json
{
  "jsonrpc": "2.0",
  "method": "tasks/send",
  "params": {
    "message": {
      "parts": [
        {
          "type": "text",
          "text": "Scan https://github.com/example/myapp for quantum vulnerabilities"
        }
      ]
    }
  },
  "id": 1
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "id": "<scan-uuid>",
    "status": { "state": "submitted", "timestamp": "..." },
    "metadata": { "repoUrl": "https://github.com/example/myapp", "scanUrl": "..." }
  }
}
```

### tasks/get

Poll until state is `"completed"`:

```json
{
  "jsonrpc": "2.0",
  "method": "tasks/get",
  "params": { "id": "<scan-uuid>" },
  "id": 2
}
```

When complete, `result.artifacts` contains:
- `scan-summary` (text/plain) — human-readable risk summary
- `cbom-eip7789` (application/json) — full CBOM manifest

---

## Why a Shared Extension Key?

A2A orchestrators (MCP hosts, multi-agent pipelines) need a convention to identify CBOM-producing agents without reading every AgentCard description field with an LLM. The `extensions` mechanism in A2A is designed exactly for this: discoverable, schema-bound, namespace-scoped capability declarations.

Using a shared key (`quantumscan.io/cbom`) means any A2A client can:

```typescript
const hasCBOM = "quantumscan.io/cbom" in agentCard.extensions;
const formats = agentCard.extensions["quantumscan.io/cbom"].supportedOutputFormats;
```

This makes automated PQC compliance pipelines — "scan → aggregate CBOMs → register on-chain → generate audit report" — composable without per-agent integration work.

---

## Relationship to Existing Standards

| Standard | Relationship |
|---|---|
| **CycloneDX CBOM 1.6** (OWASP) | `"cyclonedx-cbom-1.6"` output format |
| **EIP-7789** (Ethereum) | `"eip-7789-json"` output format; adds `quantumRiskScore` and block-number timestamps |
| **NIST FIPS 203/204/205** | All migration targets reference these standards |
| **A2A Protocol v1.0** | Uses the `extensions` field defined in the A2A AgentCard schema |

---

## Open Questions

1. Should this extension key be moved to a neutral namespace (e.g., `owasp.org/cbom` or `cisa.gov/cbom`) to encourage adoption beyond a single vendor?
2. Should a `role` field (`"producer"` vs `"consumer"`) be added to distinguish agents that produce CBOMs from those that consume them (e.g., a compliance reporter)?
3. Should `algorithmRegistryUrl` point to a canonical, versioned registry (similar to the OID registry for X.509)?

Feedback welcome via issues in this repository.
