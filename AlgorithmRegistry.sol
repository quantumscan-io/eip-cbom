// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title AlgorithmRegistry — EIP-7789 human-readable algorithm name lookup
/// @notice Maps bytes32 algorithmId → canonical name string.
/// Deployed once per chain; contracts reference it for off-chain UX without
/// paying string storage costs themselves.
contract AlgorithmRegistry {

    mapping(bytes32 => string) private _names;
    address public immutable owner;

    event AlgorithmRegistered(bytes32 indexed id, string name);

    constructor() {
        owner = msg.sender;
        // Pre-populate canonical names from EIP-7789 Appendix A
        _register("ECDSA");
        _register("RSA");
        _register("ECDH");
        _register("DSA");
        _register("BLS12-381");
        _register("Ed25519");
        _register("X25519");
        _register("keccak256");
        _register("SHA-256");
        _register("AES-128-GCM");
        _register("AES-256-GCM");
        _register("SHA3-256");
        _register("ML-KEM-512");
        _register("ML-KEM-768");
        _register("ML-KEM-1024");
        _register("ML-DSA-44");
        _register("ML-DSA-65");
        _register("ML-DSA-87");
        _register("SLH-DSA");
        _register("BLAKE3");
    }

    function _register(string memory name) private {
        bytes32 id = keccak256(bytes(name));
        _names[id] = name;
        emit AlgorithmRegistered(id, name);
    }

    /// @notice Look up human-readable name for an algorithmId.
    /// Returns empty string if unknown (custom/proprietary algorithm).
    function nameOf(bytes32 algorithmId) external view returns (string memory) {
        return _names[algorithmId];
    }

    /// @notice Register a new algorithm (owner only — governance-controlled).
    function register(string calldata name) external {
        require(msg.sender == owner, "AlgorithmRegistry: not owner");
        _register(name);
    }

    /// @notice Batch lookup for UI efficiency.
    function namesOf(bytes32[] calldata ids) external view returns (string[] memory result) {
        result = new string[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _names[ids[i]];
        }
    }
}
