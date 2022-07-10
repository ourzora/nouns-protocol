// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {IGovernorTimelockUpgradeable, GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {IGovernorUpgradeable, GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";
import {GovernorStorageV1} from "./storage/GovernorStorageV1.sol";
import {IGovernor} from "./IGovernor.sol";
import {ITreasury} from "../treasury/ITreasury.sol";
import {IToken} from "../../token/IToken.sol";

/// @title Governor
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOLogicV1.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Governor is UUPSUpgradeable, OwnableUpgradeable, GovernorTimelockControlUpgradeable, GovernorCountingSimpleUpgradeable, GovernorStorageV1 {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable upgradeManager;

    constructor(address _upgradeManager) payable initializer {
        upgradeManager = IUpgradeManager(_upgradeManager);
    }

    ///                                                          ///
    ///                          INITIALIZER                     ///
    ///                                                          ///

    function initialize(
        address _treasury,
        address _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThresholdBPS,
        uint256 _quorumVotesBPS
    ) public initializer {
        govMeta.token = IToken(_token);
        govMeta.votingPeriod = uint32(_votingPeriod);
        govMeta.votingDelay = uint32(_votingDelay);
        govMeta.proposalThresholdBPS = uint16(_proposalThresholdBPS);
        govMeta.quorumVotesBPS = uint16(_quorumVotesBPS);

        __GovernorTimelockControl_init(TimelockControllerUpgradeable(payable(_treasury)));

        __Governor_init(string.concat(govMeta.token.name(), " Governor"));

        __Ownable_init();

        transferOwnership(_treasury);
    }

    ///                                                          ///
    ///                        PUBLIC OVERRIDES                  ///
    ///                                                          ///

    function proposalThreshold() public view override returns (uint256) {
        return bps2Uint(govMeta.token.totalSupply(), govMeta.proposalThresholdBPS);
    }

    function quorum(uint256 _blockNumber) public view override returns (uint256) {
        return bps2Uint(govMeta.token.getPastTotalSupply(_blockNumber), govMeta.quorumVotesBPS);
    }

    function votingDelay() public view override(IGovernorUpgradeable) returns (uint256) {
        return govMeta.votingDelay;
    }

    function votingPeriod() public view virtual override(IGovernorUpgradeable) returns (uint256) {
        return govMeta.votingPeriod;
    }

    function state(uint256 _proposalId) public view override(GovernorTimelockControlUpgradeable, GovernorUpgradeable) returns (ProposalState) {
        return super.state(_proposalId);
    }

    function supportsInterface(bytes4 _interfaceId) public view override(GovernorTimelockControlUpgradeable, GovernorUpgradeable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    ///                                                          ///
    ///                       INTERNAL OVERRIDES                 ///
    ///                                                          ///

    function _getVotes(
        address _account,
        uint256 _blockNumber,
        bytes memory
    ) internal view override returns (uint256) {
        return govMeta.token.getPastVotes(_account, _blockNumber);
    }

    function _executor() internal view virtual override(GovernorTimelockControlUpgradeable, GovernorUpgradeable) returns (address) {
        return super._executor();
    }

    function _execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal override(GovernorTimelockControlUpgradeable, GovernorUpgradeable) {
        super._execute(_proposalId, _targets, _values, _calldatas, _descriptionHash);
    }

    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal override(GovernorTimelockControlUpgradeable, GovernorUpgradeable) returns (uint256) {
        return super._cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    ///                                                          ///
    ///                             UTILS                        ///
    ///                                                          ///

    function bps2Uint(uint256 _number, uint256 _bps) internal pure returns (uint256 result) {
        assembly {
            result := div(mul(_number, _bps), 10000)
        }
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(upgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
