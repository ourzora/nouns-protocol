// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {IGovernorTimelockUpgradeable, GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {IGovernorUpgradeable, GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IUpgradeManager} from "../../upgrade/IUpgradeManager.sol";
import {GovernorStorageV1, ITreasury, IToken} from "./storage/GovernorStorageV1.sol";
import {IGovernor} from "./IGovernor.sol";

/// @title Governor
/// @author Rohan Kulkarni
/// @notice Modified version of NounsDAOLogicV1.sol (commit 2cbe6c7) that NounsDAO licensed under the GPL-3.0 license
contract Governor is GovernorStorageV1, GovernorTimelockControlUpgradeable, GovernorCountingSimpleUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    IUpgradeManager private immutable UpgradeManager;

    constructor(address _upgradeManager) payable initializer {
        UpgradeManager = IUpgradeManager(_upgradeManager);
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
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(payable(_treasury)));

        __Governor_init(""); // TODO update solc and use string.concat w/ token name

        __Ownable_init();

        transferOwnership(_treasury);

        treasury = ITreasury(_treasury);
        token = IToken(_token);

        VOTING_PERIOD = _votingPeriod;
        VOTING_DELAY = _votingDelay;
        PROPOSAL_THRESHOLD_BPS = _proposalThresholdBPS;
        QUORUM_VOTES_BPS = _quorumVotesBPS;
    }

    ///                                                          ///
    ///                        PUBLIC OVERRIDES                  ///
    ///                                                          ///

    function proposalThreshold() public view override returns (uint256) {
        return bps2Uint(token.totalSupply(), PROPOSAL_THRESHOLD_BPS);
    }

<<<<<<< HEAD
        temp.totalSupply = token.totalSupply();
=======
    function quorum(uint256 blockNumber) public view override returns (uint256) {
        return bps2Uint(token.getPastTotalSupply(blockNumber), QUORUM_VOTES_BPS);
    }
>>>>>>> main

    function votingDelay() public view override(IGovernorUpgradeable) returns (uint256) {
        return VOTING_DELAY;
    }

    function votingPeriod() public view virtual override(IGovernorUpgradeable) returns (uint256) {
        return VOTING_PERIOD;
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
        return token.getPastVotes(_account, _blockNumber);
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

    function bps2Uint(uint256 _number, uint256 _bps) internal pure returns (uint256) {
        return (_number * _bps) / 10_000;
    }

    ///                                                          ///
    ///                         PROXY UPGRADE                    ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract to a valid implementation
    /// @dev This function is called in UUPS `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The address of the new implementation
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {
        // Ensure the implementation is valid
        require(UpgradeManager.isValidUpgrade(_getImplementation(), _newImpl), "INVALID_UPGRADE");
    }
}
