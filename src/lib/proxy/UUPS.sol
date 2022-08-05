// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC1822Proxiable} from "./IERC1822.sol";
import {Address} from "../utils/Address.sol";
import {StorageSlot} from "../utils/StorageSlot.sol";

abstract contract UUPS {
    /// @dev keccak256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /// @dev keccak256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address private immutable __self = address(this);

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function _authorizeUpgrade(address _impl) internal virtual;

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    modifier onlyProxy() {
        require(address(this) != __self, "ONLY_DELEGATECALL");
        require(_implementation() == __self, "ONLY_PROXY");
        _;
    }

    /// @dev Returns the current implementation address.
    function _implementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    event Upgraded(address impl);

    /// @dev Upgrade the proxy implementation
    function upgradeTo(address _impl) external onlyProxy {
        _authorizeUpgrade(_impl);
        _upgradeToAndCallUUPS(_impl, "", false);
    }

    /// @dev Upgrade the proxy implementation with an additional setup call
    function upgradeToAndCall(address _impl, bytes memory _data) external payable onlyProxy {
        _authorizeUpgrade(_impl);
        _upgradeToAndCallUUPS(_impl, _data, true);
    }

    /// @dev Upgrade the proxy implementation with security checks for UUPS proxies and an additional setup call
    function _upgradeToAndCallUUPS(
        address _impl,
        bytes memory _data,
        bool _forceCall
    ) internal {
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(_impl);
        } else {
            try IERC1822Proxiable(_impl).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "INVALID_UUID");
            } catch {
                revert("NOT_UUPS");
            }

            _upgradeToAndCall(_impl, _data, _forceCall);
        }
    }

    /// @dev Perform implementation upgrade with additional setup call.
    function _upgradeToAndCall(
        address _impl,
        bytes memory _data,
        bool _forceCall
    ) internal {
        _upgradeTo(_impl);

        if (_data.length > 0 || _forceCall) {
            Address.functionDelegateCall(_impl, _data);
        }
    }

    /// @dev Perform the implementation upgrade
    function _upgradeTo(address _impl) internal {
        _setImplementation(_impl);

        emit Upgraded(_impl);
    }

    /// @dev Stores a new address in the EIP1967 implementation slot
    function _setImplementation(address _impl) private {
        require(Address.isContract(_impl), "INVALID_TARGET");

        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = _impl;
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    modifier notDelegated() {
        require(address(this) == __self, "NO_DELEGATECALL");
        _;
    }

    function proxiableUUID() external view notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }
}
