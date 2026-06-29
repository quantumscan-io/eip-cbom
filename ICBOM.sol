// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title ICBOM — On-Chain Cryptographic Bill of Materials
/// @notice EIP-7789 standard interface for declaring cryptographic primitive inventory
/// @dev Implement this interface and supportsInterface(0x[TBD]) for ERC-165 discovery
interface ICBOM {

    enum PrimitiveType {
        SIGNATURE,
        KEM,
        HASH,
        SYMMETRIC,
        KDF,
        COMMITMENT,
        ZK_PROOF
    }

    enum QuantumStatus {
        VULNERABLE,
        PARTIALLY_SAFE,
        SAFE,
        UNKNOWN
    }

    struct CryptoPrimitive {
        string id;
        PrimitiveType ptype;
        string algorithm;
        uint16 keyBits;
        string purpose;
        QuantumStatus qstatus;
        string migrationTarget;
        uint64 addedAt;
    }

    /// @notice Returns all cryptographic primitives used by this contract
    function cryptoPrimitives() external view returns (CryptoPrimitive[] memory);

    /// @notice Returns the CBOM specification version (e.g., "1.0.0")
    function cbomVersion() external pure returns (string memory);

    /// @notice Returns quantum risk score 0–100 (0 = fully safe, 100 = all vulnerable)
    function quantumRiskScore() external view returns (uint8);

    event PrimitiveAdded(string indexed id, string algorithm, QuantumStatus qstatus);
    event PrimitiveUpdated(string indexed id, QuantumStatus oldStatus, QuantumStatus newStatus);
}
