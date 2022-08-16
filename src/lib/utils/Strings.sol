// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/// @notice Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    error INSUFFICIENT_HEX_LENGTH();

    function toString(uint256 _value) internal pure returns (string memory) {
        unchecked {
            if (_value == 0) {
                return "0";
            }

            uint256 temp = _value;
            uint256 digits;

            while (temp != 0) {
                digits++;

                temp /= 10;
            }

            bytes memory buffer = new bytes(digits);

            while (_value != 0) {
                digits -= 1;

                buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));

                _value /= 10;
            }

            return string(buffer);
        }
    }

    function toHexString(uint256 _value) internal pure returns (string memory) {
        unchecked {
            if (_value == 0) {
                return "0x00";
            }

            uint256 temp = _value;

            uint256 length = 0;

            while (temp != 0) {
                length++;

                temp >>= 8;
            }
            return toHexString(_value, length);
        }
    }

    function toHexString(uint256 _value, uint256 length) internal pure returns (string memory) {
        unchecked {
            uint256 bufferSize = 2 * length + 2;

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

    function toHexString(address _addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(_addr)), 20);
    }
}
