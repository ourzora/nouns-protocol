// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        _mint(_to, _tokenId, _amount, "");
    }

    function mintBatch(
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) public {
        _mintBatch(_to, _tokenIds, _amounts, "");
    }
}
