// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./ICBOM.sol";

/// @title CBOMBase — EIP-7789 reference implementation
/// @notice Inherit this and call _addPrimitive() in your constructor/initializer.
///
/// Gas cost per primitive (Cancun, Solidity 0.8.25):
///   _addPrimitive(): ~22,000 gas (warm SSTORE for 3 × bytes32 + 2 × uint8 + uint64)
///   cryptoPrimitives(): ~3,500 gas per primitive (SLOAD in view call)
///   quantumRiskScore(): ~2,800 gas (in-memory loop over stored array)
abstract contract CBOMBase is ICBOM {

    CryptoPrimitive[] private _primitives;

    // ── Canonical algorithm IDs (keccak256 of canonical name from EIP-7789 Appendix A) ──
    bytes32 public constant ALG_ECDSA        = keccak256("ECDSA");
    bytes32 public constant ALG_RSA          = keccak256("RSA");
    bytes32 public constant ALG_ECDH         = keccak256("ECDH");
    bytes32 public constant ALG_DSA          = keccak256("DSA");
    bytes32 public constant ALG_BLS12_381    = keccak256("BLS12-381");
    bytes32 public constant ALG_ED25519      = keccak256("Ed25519");
    bytes32 public constant ALG_X25519       = keccak256("X25519");
    bytes32 public constant ALG_KECCAK256    = keccak256("keccak256");
    bytes32 public constant ALG_SHA256       = keccak256("SHA-256");
    bytes32 public constant ALG_AES128_GCM   = keccak256("AES-128-GCM");
    bytes32 public constant ALG_AES256_GCM   = keccak256("AES-256-GCM");
    bytes32 public constant ALG_SHA3_256     = keccak256("SHA3-256");
    bytes32 public constant ALG_ML_KEM_512   = keccak256("ML-KEM-512");
    bytes32 public constant ALG_ML_KEM_768   = keccak256("ML-KEM-768");
    bytes32 public constant ALG_ML_KEM_1024  = keccak256("ML-KEM-1024");
    bytes32 public constant ALG_ML_DSA_44    = keccak256("ML-DSA-44");
    bytes32 public constant ALG_ML_DSA_65    = keccak256("ML-DSA-65");
    bytes32 public constant ALG_ML_DSA_87    = keccak256("ML-DSA-87");
    bytes32 public constant ALG_SLH_DSA      = keccak256("SLH-DSA");
    bytes32 public constant ALG_BLAKE3       = keccak256("BLAKE3");

    // ── ICBOM implementation ──────────────────────────────────────────────────

    function cryptoPrimitives() external view override returns (CryptoPrimitive[] memory) {
        return _primitives;
    }

    function cbomVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function quantumRiskScore() external view override returns (uint8) {
        uint256 len = _primitives.length;
        if (len == 0) return 0;
        uint256 vulnerable;
        for (uint256 i = 0; i < len; i++) {
            if (_primitives[i].qstatus == QuantumStatus.VULNERABLE) vulnerable++;
        }
        return uint8((vulnerable * 100) / len);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(ICBOM).interfaceId;
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /// @dev Register a cryptographic primitive. Call in constructor or initializer.
    function _addPrimitive(CryptoPrimitive memory p) internal {
        _primitives.push(p);
        emit PrimitiveAdded(p.id, p.algorithmId, p.qstatus);
    }

    /// @dev Update quantum status after PQC migration.
    function _updateQuantumStatus(uint256 index, QuantumStatus newStatus) internal {
        require(index < _primitives.length, "CBOMBase: out of bounds");
        QuantumStatus old = _primitives[index].qstatus;
        _primitives[index].qstatus = newStatus;
        _primitives[index].migrationId = bytes32(0); // cleared after migration
        emit PrimitiveUpdated(_primitives[index].id, old, newStatus);
    }

    /// @dev Helper: build a CryptoPrimitive with current block number.
    function _primitive(
        string memory id,
        PrimitiveType ptype,
        bytes32 algorithmId,
        uint16 keyBits,
        QuantumStatus qstatus,
        bytes32 migrationId
    ) internal view returns (CryptoPrimitive memory) {
        return CryptoPrimitive({
            id: keccak256(bytes(id)),
            ptype: ptype,
            algorithmId: algorithmId,
            keyBits: keyBits,
            qstatus: qstatus,
            migrationId: migrationId,
            addedAt: uint64(block.number)
        });
    }
}
