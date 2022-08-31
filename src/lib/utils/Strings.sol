// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Modified from OpenZeppelin Contracts v4.7.3 (utils/Strings.sol)
/// - Uses custom error `INSUFFICIENT_HEX_LENGTH()`
/// - Unchecks both overflow (unrealistic) and underflow (protected)
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    error INSUFFICIENT_HEX_LENGTH();

    /// @dev Converts a `uint256` to its ASCII `string` decimal representation.
    function toString(uint256 _value) internal pure returns (string memory) {
        unchecked {
            if (_value == 0) {
                return "0";
            }

            uint256 temp = _value;
            uint256 digits;

            while (temp != 0) {
                ++digits;

                temp /= 10;
            }

            bytes memory buffer = new bytes(digits);

            while (_value != 0) {
                --digits;

                buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));

                _value /= 10;
            }

            return string(buffer);
        }
    }

    /// @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
    function toHexString(uint256 _value) internal pure returns (string memory) {
        unchecked {
            if (_value == 0) {
                return "0x00";
            }

            uint256 temp = _value;
            uint256 length;

            while (temp != 0) {
                ++length;

                temp >>= 8;
            }
            return toHexString(_value, length);
        }
    }

    /// @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
    function toHexString(uint256 _value, uint256 _length) internal pure returns (string memory) {
        unchecked {
            uint256 bufferSize = 2 * _length + 2;

            bytes memory buffer = new bytes(bufferSize);

            buffer[0] = "0";
            buffer[1] = "x";

            uint256 start = bufferSize - 1;

            for (uint256 i = start; i > 1; --i) {
                buffer[i] = _HEX_SYMBOLS[_value & 0xf];

                _value >>= 4;
            }

            if (_value != 0) revert INSUFFICIENT_HEX_LENGTH();

            return string(buffer);
        }
    }

    /// @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
    function toHexString(address _addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(_addr)), 20);
    }
}
