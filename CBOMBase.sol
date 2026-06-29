// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./ICBOM.sol";

/// @title CBOMBase — EIP-7789 reference implementation
/// @notice Inherit this contract and call _addPrimitive() in your constructor
abstract contract CBOMBase is ICBOM {

    CryptoPrimitive[] private _primitives;

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

    function _addPrimitive(CryptoPrimitive memory p) internal {
        _primitives.push(p);
        emit PrimitiveAdded(p.id, p.algorithm, p.qstatus);
    }

    function _updateQuantumStatus(uint256 index, QuantumStatus newStatus) internal {
        require(index < _primitives.length, "CBOMBase: out of bounds");
        QuantumStatus old = _primitives[index].qstatus;
        _primitives[index].qstatus = newStatus;
        emit PrimitiveUpdated(_primitives[index].id, old, newStatus);
    }
}
