// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./ICBOM.sol";

/// @title CBOMRegistry — EIP-7789 global registry for non-upgradeable contracts
/// @notice Allows contracts that cannot implement ICBOM directly to register a separate CBOM
contract CBOMRegistry {

    mapping(address => address) public cbomOf;

    event CBOMRegistered(address indexed contractAddr, address indexed cbomImpl, address registrant);

    function register(address contractAddr, address cbomImpl) external {
        require(
            bytes(ICBOM(cbomImpl).cbomVersion()).length > 0,
            "CBOMRegistry: cbomImpl must implement ICBOM"
        );
        cbomOf[contractAddr] = cbomImpl;
        emit CBOMRegistered(contractAddr, cbomImpl, msg.sender);
    }

    /// @notice Resolves the CBOM for a contract — direct implementation or registry entry
    function resolve(address contractAddr) external view returns (address) {
        (bool ok, bytes memory result) = contractAddr.staticcall(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(ICBOM).interfaceId)
        );
        if (ok && result.length == 32 && abi.decode(result, (bool))) {
            return contractAddr;
        }
        return cbomOf[contractAddr];
    }
}
