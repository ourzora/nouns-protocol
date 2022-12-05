// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @dev Encode and decode base64 url
 * @author hiromin <tannguyen1742@gmail.com>
 */
library Base64URIDecoder {
    /**
        @dev fast way to calculate this index table in python:
               encode_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
               table = [None] * 256
               for i in range(len(encode_table)): # len = 64
                   table[ord(encode_table[i])] = bytes([i]).hex()
     */
    bytes internal constant DECODING_TABLE =
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
        hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
        hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function decodeURI(bytes memory expectedPrefix, string memory base64Url) internal pure returns (string memory) {
        bytes memory base64UrlBytes = bytes(base64Url);

        uint256 splitAt = 0;
        for (uint256 i = 0; i < base64UrlBytes.length; i++) {
            if (base64UrlBytes[i] == bytes1(0x2c)) {
                splitAt = i + 1;
                break;
            }
        }

        bytes memory splitTest = new bytes(splitAt);
        for (uint256 i = 0; i < splitAt; i++) {
            splitTest[i] = base64UrlBytes[i];
        }

        assert(keccak256(expectedPrefix) == keccak256(splitTest));

        uint256 stringSize = base64UrlBytes.length - splitAt;
        bytes memory retValue = new bytes(stringSize);
        for (uint256 i = splitAt; i < base64UrlBytes.length; i++) {
            retValue[i - splitAt] = base64UrlBytes[i];
        }
        return decode(string(retValue));
    }

    function decode(string memory base64Url) internal pure returns (string memory) {
        bytes memory data = bytes(base64Url);

        require(data.length > 0, "Invalid base64 string");

        if (data.length == 0) return "";

        // When decoding base64 string, 4 characters are converted back to 3 bytes, skip padding "="
        uint256 decodedLength = (data.length / 4) * 3;

        if (data[data.length - 1] == "=") {
            decodedLength--;
            if (data[data.length - 2] == "=") decodedLength--;
        }

        // Load the table into memory
        bytes memory table = DECODING_TABLE;

        bytes memory result = new bytes(decodedLength);

        // @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 4 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 4 bytes
                dataPtr := add(dataPtr, 4)
                let input := mload(dataPtr)

                // write 3 bytes
                let output := add(
                    add(
                        shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                        shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))
                    ),
                    add(shl(6, and(mload(add(tablePtr, and(shr(8, input), 0xFF))), 0xFF)), and(mload(add(tablePtr, and(input, 0xFF))), 0xFF))
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }
        return string(result);
    }
}
