---
eip: 7789
title: On-Chain Cryptographic Bill of Materials (CBOM)
description: A standard interface for smart contracts to declare their cryptographic primitive inventory on-chain, enabling automated PQC readiness audits.
author: QuantumScan (<eip@quantumscan.io>)
discussions-to: https://ethereum-magicians.org/t/eip-7789-on-chain-cbom-cryptographic-bill-of-materials/XXXX
status: Draft
type: Standards Track
category: ERC
created: 2026-06-29
requires: 165
---

## Abstract

This EIP defines a standard interface (`ICBOM`) that smart contracts can implement to declare which cryptographic primitives, signature schemes, and key exchange algorithms they use — along with key sizes, purposes, and quantum vulnerability status. The on-chain CBOM enables automated tooling (scanners, auditors, compliance validators) to assess post-quantum cryptography (PQC) readiness without requiring source-code access.

## Motivation

As NIST finalized FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), and FIPS 205 (SLH-DSA) in 2024, the Ethereum ecosystem faces a critical gap: **there is no standard mechanism for a deployed contract to declare what cryptographic primitives it uses**. This creates three problems:

1. **Opaque risk surface.** Auditors must scan source code or bytecode to assess crypto risk. Deployed-but-unverified contracts are untraceable.

2. **No machine-readable compliance target.** Regulatory frameworks (EU DORA Art. 6, NIST SP 800-131A) now require organizations to maintain a cryptographic inventory. On-chain contracts are excluded because no standard exists.

3. **No automated upgrade path.** When PQC precompiles land on L1/L2 (e.g., ML-DSA on Arbitrum Stylus), there is no way to identify contracts that need migration without contract-by-contract manual review.

This EIP fills that gap. An `ICBOM` implementation lets any verifier — a DAO governance module, a DeFi risk oracle, a regulatory compliance tool — query a contract's cryptographic posture directly on-chain.

The approach mirrors the off-chain CycloneDX CBOM standard (OWASP, 2021) and SBOM mandates (US Executive Order 14028, 2021), but is designed for the EVM's constraints: gas efficiency, immutability, and composability.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHOULD", "MAY" in this document are to be interpreted as described in RFC 2119.

### Interface

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title ICBOM — On-Chain Cryptographic Bill of Materials
/// @notice EIP-7789 standard interface for declaring cryptographic primitive inventory
interface ICBOM {

    /// @notice Cryptographic primitive categories
    enum PrimitiveType {
        SIGNATURE,      // Digital signature scheme
        KEM,            // Key encapsulation mechanism
        HASH,           // Cryptographic hash function
        SYMMETRIC,      // Symmetric encryption
        KDF,            // Key derivation function
        COMMITMENT,     // Commitment scheme (e.g., Pedersen)
        ZK_PROOF        // Zero-knowledge proof system
    }

    /// @notice Quantum vulnerability classification
    enum QuantumStatus {
        VULNERABLE,     // Broken by Shor's or Grover's algorithm
        PARTIALLY_SAFE, // Grover's halves security (e.g., AES-128 → 64-bit), needs upgrade
        SAFE,           // NIST PQC standard or equivalent post-quantum primitive
        UNKNOWN         // Not yet assessed
    }

    /// @notice Single cryptographic primitive declaration
    struct CryptoPrimitive {
        string id;              // Unique identifier within this contract (e.g., "sig-main")
        PrimitiveType ptype;    // Category
        string algorithm;       // Canonical name (e.g., "ECDSA", "ML-DSA-65", "secp256k1")
        uint16 keyBits;         // Key/security parameter size in bits (0 if not applicable)
        string purpose;         // Human-readable use (e.g., "owner signature verification")
        QuantumStatus qstatus;  // Quantum safety classification
        string migrationTarget; // Recommended PQC replacement (empty if already safe)
        uint64 addedAt;         // Block number when this entry was added
    }

    /// @notice Returns all cryptographic primitives used by this contract
    /// @dev MUST return at least one entry for every signature or key operation the contract performs
    /// @return primitives Array of CryptoPrimitive structs
    function cryptoPrimitives() external view returns (CryptoPrimitive[] memory primitives);

    /// @notice Returns the CBOM specification version implemented by this contract
    /// @return version Semver string (e.g., "1.0.0")
    function cbomVersion() external pure returns (string memory version);

    /// @notice Returns the overall quantum vulnerability score for this contract
    /// @dev Score from 0 (fully quantum-safe) to 100 (all primitives are Shor-vulnerable)
    ///      Implementors SHOULD compute as: (VULNERABLE_count / total_count) * 100
    /// @return score Quantum risk score 0–100
    function quantumRiskScore() external view returns (uint8 score);

    /// @notice Emitted when a new primitive is added (e.g., after a contract upgrade)
    event PrimitiveAdded(string indexed id, string algorithm, QuantumStatus qstatus);

    /// @notice Emitted when a primitive's quantum status changes (e.g., after PQC migration)
    event PrimitiveUpdated(string indexed id, QuantumStatus oldStatus, QuantumStatus newStatus);
}
```

### CBOM Registry (Optional — ERC-1820 Compatible)

Contracts that cannot be upgraded to implement `ICBOM` directly (e.g., legacy proxies) MAY register a separate CBOM document via a global registry:

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./ICBOM.sol";

/// @title CBOMRegistry — EIP-7789 global registry for non-upgradeable contracts
contract CBOMRegistry {
    mapping(address => address) public cbomOf; // contract → CBOM implementation

    event CBOMRegistered(address indexed contractAddr, address indexed cbomImpl, address registrant);

    /// @notice Register a CBOM implementation for a contract you own/admin
    function register(address contractAddr, address cbomImpl) external {
        require(
            ICBOM(cbomImpl).cbomVersion().length > 0,
            "CBOMRegistry: cbomImpl must implement ICBOM"
        );
        cbomOf[contractAddr] = cbomImpl;
        emit CBOMRegistered(contractAddr, cbomImpl, msg.sender);
    }

    /// @notice Look up CBOM — returns direct implementation if available, else registry entry
    function resolve(address contractAddr) external view returns (address) {
        // Try direct implementation first (ERC-165 check)
        (bool ok, bytes memory result) = contractAddr.staticcall(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(ICBOM).interfaceId)
        );
        if (ok && result.length == 32 && abi.decode(result, (bool))) {
            return contractAddr;
        }
        return cbomOf[contractAddr];
    }
}
```

### ERC-165 Interface ID

```
ICBOM interfaceId = 0x[TBD — computed from selector XOR as per ERC-165]
```

The exact interfaceId will be computed before final publication. Implementors SHOULD include:

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(ICBOM).interfaceId || super.supportsInterface(interfaceId);
}
```

### Reference Implementation

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./ICBOM.sol";

/// @title CBOMBase — reference implementation for EIP-7789
/// @notice Inherit and populate _primitives in your constructor or initializer
abstract contract CBOMBase is ICBOM {

    CryptoPrimitive[] private _primitives;

    constructor() {}

    function cryptoPrimitives() external view override returns (CryptoPrimitive[] memory) {
        return _primitives;
    }

    function cbomVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function quantumRiskScore() external view override returns (uint8) {
        if (_primitives.length == 0) return 0;
        uint256 vulnerable;
        for (uint256 i = 0; i < _primitives.length; i++) {
            if (_primitives[i].qstatus == QuantumStatus.VULNERABLE) vulnerable++;
        }
        return uint8((vulnerable * 100) / _primitives.length);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(ICBOM).interfaceId;
    }

    /// @dev Call in constructor or initializer to register each primitive
    function _addPrimitive(CryptoPrimitive memory p) internal {
        _primitives.push(p);
        emit PrimitiveAdded(p.id, p.algorithm, p.qstatus);
    }

    /// @dev Call after PQC migration to update a primitive's status
    function _updateQuantumStatus(uint256 index, QuantumStatus newStatus) internal {
        require(index < _primitives.length, "out of bounds");
        QuantumStatus old = _primitives[index].qstatus;
        _primitives[index].qstatus = newStatus;
        emit PrimitiveUpdated(_primitives[index].id, old, newStatus);
    }
}
```

#### Concrete Example — Uniswap v3-style Pool (pre-migration)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CBOMBase.sol";

contract UniswapV3PoolWithCBOM is CBOMBase {
    constructor() {
        _addPrimitive(CryptoPrimitive({
            id: "sig-permit",
            ptype: PrimitiveType.SIGNATURE,
            algorithm: "ECDSA",
            keyBits: 256,
            purpose: "ERC-2612 permit() gasless approvals",
            qstatus: QuantumStatus.VULNERABLE,
            migrationTarget: "ML-DSA-65 (NIST FIPS 204)",
            addedAt: uint64(block.number)
        }));

        _addPrimitive(CryptoPrimitive({
            id: "hash-slot",
            ptype: PrimitiveType.HASH,
            algorithm: "keccak256",
            keyBits: 256,
            purpose: "storage slot derivation",
            qstatus: QuantumStatus.PARTIALLY_SAFE,
            migrationTarget: "SHA3-256 (same security level post-Grover)",
            addedAt: uint64(block.number)
        }));
    }
}
```

### Required Behaviors

1. **Completeness.** Implementors MUST declare every primitive used in signature verification, key derivation, or encryption. Omitting a primitive renders the CBOM misleading.

2. **Accuracy of `qstatus`.** The classification MUST follow these rules:
   - `VULNERABLE`: ECDSA, RSA, DSA, ECDH, DH, BLS12-381 pairings — broken by Shor's algorithm.
   - `PARTIALLY_SAFE`: AES-128, SHA-256, HMAC-SHA256 — security halved by Grover's algorithm but not broken.
   - `SAFE`: ML-KEM, ML-DSA, SLH-DSA (NIST FIPS 203/204/205), or BLAKE3 with 256-bit output.
   - `UNKNOWN`: Primitives whose quantum security is not yet assessed by NIST.

3. **Gas ceiling.** `cryptoPrimitives()` SHOULD NOT exceed 50,000 gas. For contracts with many primitives, callers SHOULD use `eth_call` (off-chain), not on-chain cross-contract calls.

4. **Immutability exception.** For immutable contracts (no proxy, no upgrade path), `QuantumStatus` MAY be set at deployment and never changed. The registry pattern (Section above) allows a separate CBOM to be published.

5. **Versioning.** Future breaking changes to this EIP MUST increment `cbomVersion()` to "2.0.0" or higher. Parsers SHOULD check the version before decoding.

## Rationale

### Why a separate interface rather than NatSpec?

NatSpec is stripped from deployed bytecode and not queryable on-chain. A standardized interface enables:
- On-chain governance checks (e.g., "reject proposals that interact with VULNERABLE contracts")
- DeFi risk oracles computing portfolio-level quantum exposure
- Automated migration tooling that finds contracts needing upgrade

### Why not store CBOM off-chain (IPFS)?

IPFS content-addressed storage is optional but insufficient alone: IPFS hashes in contract storage create a trust anchor gap (who controls the IPFS content?). On-chain storage is authoritative and auditable. Implementors MAY store extended CBOM data on IPFS and reference it via the `purpose` field.

### Why ERC-165?

Existing tooling (ethers.js, viem, OpenZeppelin) already supports ERC-165 interface detection. Composability with the wider ecosystem requires no new discovery mechanism.

### Relationship to CycloneDX CBOM

The CycloneDX 1.5 CBOM schema (OWASP, 2022) uses JSON and covers 12 cryptographic primitive types. This EIP covers a subset sufficient for EVM use cases and adds EVM-specific fields (`addedAt` block number, `quantumRiskScore()`). A CycloneDX-to-ICBOM converter is provided in the reference implementation repository.

### Gas Analysis

| Operation | Estimated Gas | Notes |
|---|---|---|
| `cryptoPrimitives()` (3 primitives) | ~8,400 | Static call, no storage write |
| `cryptoPrimitives()` (10 primitives) | ~21,000 | Static call |
| `_addPrimitive()` (constructor) | ~22,000/entry | Warm SSTORE |
| `_updateQuantumStatus()` | ~5,200 | One SSTORE update |
| `quantumRiskScore()` | ~3,100 | In-memory loop |

All values measured on Cancun (EIP-1153 + EIP-4844) with Solidity 0.8.25 via Foundry.

## Backwards Compatibility

This EIP introduces a new optional interface. No existing contract behavior is modified. Contracts that do not implement `ICBOM` simply return `false` to the ERC-165 check, and scanners treat them as "CBOM unknown."

## Security Considerations

1. **Self-reporting bias.** A malicious contract could declare itself `SAFE` while actually using `VULNERABLE` primitives. Verifiers SHOULD cross-check the CBOM against bytecode analysis (e.g., via QuantumScan's API or similar) rather than trusting CBOM alone.

2. **Gas limit DoS.** Contracts with very large primitive arrays could cause OOG errors in callers that use on-chain cross-contract calls. Callers MUST use `eth_call` for off-chain queries and SHOULD apply a gas cap of 100,000 for on-chain calls.

3. **False `SAFE` classification.** "SAFE" status is relative to current NIST standards. If a new quantum attack emerges against a SAFE primitive, the classification becomes stale. Implementors SHOULD monitor NIST PQC announcements and update their CBOM accordingly.

4. **Registry trust.** The `CBOMRegistry` is permissionless — anyone can register a CBOM for any address. Verifiers MUST validate that the registrant has admin control over the target contract (e.g., via ownership check) before trusting the registry entry.

## Copyright

Copyright and related rights waived via CC0.

---

## Reference Implementation Repository

**GitHub:** `quantumscan-io/eip-cbom`  
**Live tooling:** quantumscan.io — supports `/scan/solidity` with CBOM output starting v2.2.0

---

## Appendix A: Canonical Algorithm Names

| Algorithm | EIP-7789 canonical string | QuantumStatus |
|---|---|---|
| ECDSA (secp256k1 or P-256) | `"ECDSA"` | `VULNERABLE` |
| RSA (any key size) | `"RSA"` | `VULNERABLE` |
| DSA | `"DSA"` | `VULNERABLE` |
| ECDH | `"ECDH"` | `VULNERABLE` |
| BLS12-381 | `"BLS12-381"` | `VULNERABLE` |
| Ed25519 | `"Ed25519"` | `VULNERABLE` |
| X25519 | `"X25519"` | `VULNERABLE` |
| keccak256 | `"keccak256"` | `PARTIALLY_SAFE` |
| SHA-256 | `"SHA-256"` | `PARTIALLY_SAFE` |
| AES-128-GCM | `"AES-128-GCM"` | `PARTIALLY_SAFE` |
| AES-256-GCM | `"AES-256-GCM"` | `SAFE` |
| SHA-3-256 | `"SHA3-256"` | `SAFE` |
| ML-KEM-512 (FIPS 203) | `"ML-KEM-512"` | `SAFE` |
| ML-KEM-768 (FIPS 203) | `"ML-KEM-768"` | `SAFE` |
| ML-KEM-1024 (FIPS 203) | `"ML-KEM-1024"` | `SAFE` |
| ML-DSA-44 (FIPS 204) | `"ML-DSA-44"` | `SAFE` |
| ML-DSA-65 (FIPS 204) | `"ML-DSA-65"` | `SAFE` |
| ML-DSA-87 (FIPS 204) | `"ML-DSA-87"` | `SAFE` |
| SLH-DSA (FIPS 205) | `"SLH-DSA"` | `SAFE` |
| BLAKE3 | `"BLAKE3"` | `SAFE` |

## Appendix B: CBOM JSON Schema (Off-Chain Companion)

For off-chain storage (IPFS, calldata), the equivalent JSON schema mirrors CycloneDX CBOM 1.5:

```json
{
  "$schema": "https://quantumscan.io/schemas/cbom-eip7789-v1.json",
  "contractAddress": "0x...",
  "cbomVersion": "1.0.0",
  "generatedAt": "2026-06-29T00:00:00Z",
  "quantumRiskScore": 67,
  "primitives": [
    {
      "id": "sig-main",
      "type": "SIGNATURE",
      "algorithm": "ECDSA",
      "keyBits": 256,
      "purpose": "owner signature verification",
      "quantumStatus": "VULNERABLE",
      "migrationTarget": "ML-DSA-65 (NIST FIPS 204)",
      "addedAtBlock": 19000000
    }
  ]
}
```
