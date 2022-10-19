// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC721 } from "../../../src/lib/token/ERC721.sol";
import { UUPS } from "../../../src/lib/proxy/UUPS.sol";

contract MockERC721 is UUPS, ERC721 {
    constructor() initializer {
        __ERC721_init("Mock NFT", "MOCK");
    }

    function mint(address _to, uint256 _tokenId) public {
        _mint(_to, _tokenId);
    }

    function _authorizeUpgrade(address) internal override virtual {
        // no-op
    }
}
