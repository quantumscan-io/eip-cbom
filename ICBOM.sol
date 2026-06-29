// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title ICBOM — On-Chain Cryptographic Bill of Materials
/// @notice EIP-7789 standard interface for declaring cryptographic primitive inventory.
///
/// Design goal: gas-efficient storage using bytes32 identifiers for algorithm names.
/// Human-readable names live off-chain (EIP-7789 JSON companion) or in AlgorithmRegistry.
interface ICBOM {

    enum PrimitiveType {
        SIGNATURE,    // Digital signature scheme
        KEM,          // Key encapsulation mechanism
        HASH,         // Cryptographic hash function
        SYMMETRIC,    // Symmetric encryption
        KDF,          // Key derivation function
        COMMITMENT,   // Commitment scheme (e.g., Pedersen)
        ZK_PROOF      // Zero-knowledge proof system
    }

    enum QuantumStatus {
        VULNERABLE,     // Broken by Shor's algorithm (ECDSA, RSA, DH, BLS pairings)
        PARTIALLY_SAFE, // Grover's halves security (AES-128, SHA-256, keccak256)
        SAFE,           // NIST PQC standard: ML-KEM, ML-DSA, SLH-DSA, or BLAKE3-256
        UNKNOWN         // Not yet assessed by NIST
    }

    /// @notice Compact on-chain storage struct — uses bytes32 to avoid expensive string SSTORE.
    /// algorithmId = keccak256(abi.encodePacked(canonicalName))
    /// e.g. keccak256("ECDSA"), keccak256("ML-DSA-65"), keccak256("keccak256")
    /// See Appendix A of EIP-7789 draft for the full canonical name table.
    struct CryptoPrimitive {
        bytes32 id;           // unique within this contract, e.g. keccak256("sig-main")
        PrimitiveType ptype;
        bytes32 algorithmId;  // keccak256 of canonical algorithm name
        uint16 keyBits;       // key/security parameter size in bits (0 if not applicable)
        QuantumStatus qstatus;
        bytes32 migrationId;  // keccak256 of recommended PQC replacement (bytes32(0) if safe)
        uint64 addedAt;       // block number
    }

    /// @notice Returns all cryptographic primitives used by this contract.
    /// @dev SHOULD NOT exceed 50,000 gas. Callers MUST use eth_call for off-chain reads.
    function cryptoPrimitives() external view returns (CryptoPrimitive[] memory);

    /// @notice EIP-7789 CBOM specification version implemented by this contract.
    function cbomVersion() external pure returns (string memory);

    /// @notice Quantum risk score 0–100.
    /// 0 = all primitives are NIST PQC SAFE.
    /// 100 = all primitives are VULNERABLE.
    /// Computed as: (VULNERABLE_count / total_count) * 100
    function quantumRiskScore() external view returns (uint8);

    /// @notice Emitted when a primitive is added (e.g., after upgrade).
    event PrimitiveAdded(bytes32 indexed id, bytes32 algorithmId, QuantumStatus qstatus);

    /// @notice Emitted when a primitive's quantum status changes (e.g., after PQC migration).
    event PrimitiveUpdated(bytes32 indexed id, QuantumStatus oldStatus, QuantumStatus newStatus);
}
