// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CBOMBase.sol";

/// @title Example: Uniswap v3-style pool with EIP-7789 CBOM
/// @notice Shows how a DeFi protocol declares its cryptographic inventory.
/// This example has quantumRiskScore() = 67 (2 of 3 primitives are VULNERABLE).
contract UniswapV3PoolWithCBOM is CBOMBase {

    constructor() {
        // 1. ERC-2612 permit() — ECDSA, quantum-VULNERABLE, HNDL-exposed
        _addPrimitive(_primitive(
            "sig-permit",
            PrimitiveType.SIGNATURE,
            ALG_ECDSA,
            256,
            QuantumStatus.VULNERABLE,
            ALG_ML_DSA_65 // migration target
        ));

        // 2. EIP-712 typed data domain separator — also ECDSA-backed
        _addPrimitive(_primitive(
            "sig-eip712-domain",
            PrimitiveType.SIGNATURE,
            ALG_ECDSA,
            256,
            QuantumStatus.VULNERABLE,
            ALG_ML_DSA_65
        ));

        // 3. Storage slot derivation via keccak256 — PARTIALLY_SAFE (Grover's)
        _addPrimitive(_primitive(
            "hash-storage-slot",
            PrimitiveType.HASH,
            ALG_KECCAK256,
            256,
            QuantumStatus.PARTIALLY_SAFE,
            bytes32(0) // no migration needed immediately
        ));
    }
    // quantumRiskScore() = (2/3)*100 = 66
}
