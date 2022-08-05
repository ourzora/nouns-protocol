// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/// @notice Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function toBytes32(string memory _str) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(_str, 32))
        }
    }

    /// @dev Converts a `uint256` to its ASCII `string` decimal representation
    function toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }

        uint256 temp = _value;
        uint256 digits;

        while (temp != 0) {
            unchecked {
                ++digits;
                temp /= 10;
            }
        }

        bytes memory buffer = new bytes(digits);

        while (_value != 0) {
            unchecked {
                --digits;
                buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
                _value /= 10;
            }
        }

        return string(buffer);
    }

    /// @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation
    function toHexString(uint256 _address) internal pure returns (string memory) {
        bytes memory buffer = new bytes(42);

        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = 41; i > 1; ) {
            unchecked {
                buffer[i] = _HEX_SYMBOLS[_address & 0xf];
                _address >>= 4;

                --i;
            }
        }

        require(_address == 0, "INSUFFICIENT_HEX_LENGTH");

        return string(buffer);
    }

    /// @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
    function toHexString(uint256 _value, uint256 _length) internal pure returns (string memory) {
        // TODO more precise optimizations like caching
        unchecked {
            bytes memory buffer = new bytes(2 * _length + 2);

            buffer[0] = "0";
            buffer[1] = "x";

            for (uint256 i = 2 * _length + 1; i > 1; ) {
                buffer[i] = _HEX_SYMBOLS[_value & 0xf];
                _value >>= 4;

                --i;
            }

            require(_value == 0, "INSUFFICIENT_HEX_LENGTH");

            return string(buffer);
        }
    }
}
