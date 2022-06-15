// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "./metadata/IMetadataRenderer.sol";
import {IUpgradeManager} from "../upgrades/IUpgradeManager.sol";


interface ITokenSpec {
    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMinter(address minter) external;

    function setFoundersDAO(address foundersDAO) external;

    function totalCount() external view returns (uint256);

    function foundersDAO() external view returns (address);
    function UpgradeManager() external view returns (IUpgradeManager);

    function initialize(
        string memory _name,
        string memory _symbol,
        IMetadataRenderer _metadataRenderer,
        address _foundersDAO,
        uint256 _foundersMaxAllocation,
        uint256 _foundersAllocationFrequency,
        address _treasury,
        address _minter
    ) external;
}
