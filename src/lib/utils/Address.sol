// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

library Address {
    function toBytes32(address _account) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_account)));
    }

    function isContract(address _account) internal view returns (bool rv) {
        assembly {
            rv := gt(extcodesize(_account), 0)
        }
    }

    function sendValue(address _recipient, uint256 _value) internal {
        require(address(this).balance >= _value, "INSUFFICIENT_BALANCE");

        (bool success, ) = _recipient.call{value: _value}("");

        require(success, "TRANSFER_FAILED");
    }

    function functionCall(address _target, bytes memory _data) internal returns (bytes memory) {
        return functionCallWithValue(_target, _data, 0);
    }

    function functionCallWithValue(
        address _target,
        bytes memory _data,
        uint256 _value
    ) internal returns (bytes memory) {
        require(address(this).balance >= _value, "INSUFFICIENT_BALANCE");

        require(isContract(_target), "INVALID_TARGET");

        (bool success, bytes memory returndata) = _target.call{value: _value}(_data);

        return verifyCallResult(success, returndata, "CALL_WITH_VALUE_FAILED");
    }

    function functionStaticCall(address _target, bytes memory _data) internal view returns (bytes memory) {
        require(isContract(_target), "INVALID_TARGET");

        (bool success, bytes memory returndata) = _target.staticcall(_data);

        return verifyCallResult(success, returndata, "STATIC_CALL_FAILED");
    }

    function functionDelegateCall(address _target, bytes memory _data) internal returns (bytes memory) {
        require(isContract(_target), "INVALID_TARGET");

        (bool success, bytes memory returndata) = _target.delegatecall(_data);

        return verifyCallResult(success, returndata, "DELEGATE_CALL_FAILED");
    }

    function verifyCallResult(
        bool _success,
        bytes memory _returndata,
        string memory _errorMessage
    ) internal pure returns (bytes memory) {
        if (_success) {
            return _returndata;
        } else {
            if (_returndata.length > 0) {
                assembly {
                    let returndata_size := mload(_returndata)

                    revert(add(32, _returndata), returndata_size)
                }
            } else {
                revert(_errorMessage);
            }
        }
    }
}
