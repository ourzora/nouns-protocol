// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC1822Proxiable} from "./IERC1822.sol";
import {Address} from "../utils/Address.sol";
import {StorageSlot} from "../utils/StorageSlot.sol";

contract ERC1967Proxy {
    /// @dev keccak256("eip1967.proxy.rollback") - 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /// @dev keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    /// @notice Emitted when the implementation is upgraded
    /// @param impl The address of the implementation
    event Upgraded(address impl);

    /// @dev Performs an implementation upgrade with security checks for UUPS proxies and an additional setup call
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "INVALID_UUID");
            } catch {
                revert("NOT_UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /// @dev Upgrades an implementation with an additional setup call
    function _upgradeToAndCall(
        address _impl,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(_impl);

        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(_impl, data);
        }
    }

    /// @dev Upgrade the implementation
    function _upgradeTo(address _newImpl) internal {
        _setImplementation(_newImpl);

        emit Upgraded(_newImpl);
    }

    /// @dev Stores the implementation address
    function _setImplementation(address _newImpl) private {
        require(Address.isContract(_newImpl), "INVALID_IMPL");

        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = _newImpl;
    }

    /// @dev Gets the address of the current implementation
    function _implementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /// @dev Delegates calls to the current implementation
    receive() external payable {
        _fallback();
    }

    /// @dev Delegates calls to the current implementation
    fallback() external payable {
        _fallback();
    }

    /// @dev Delegates calls to the current implementation
    function _fallback() internal {
        _delegate(_implementation());
    }

    /// @dev Delegates a call to the given implementation contract
    /// @dev Does not return to its internal call site, it will return directly to the external caller.
    function _delegate(address _impl) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
