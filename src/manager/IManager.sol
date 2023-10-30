// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../lib/interfaces/IUUPS.sol";
import { IOwnable } from "../lib/interfaces/IOwnable.sol";

/// @title IManager
/// @author Rohan Kulkarni
/// @notice The external Manager events, errors, structs and functions
interface IManager is IUUPS, IOwnable {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a DAO is deployed
    /// @param token The ERC-721 token address
    /// @param metadata The metadata renderer address
    /// @param auction The auction address
    /// @param treasury The treasury address
    /// @param governor The governor address
    event DAODeployed(address token, address metadata, address auction, address treasury, address governor);

    /// @notice Emitted when an upgrade is registered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRegistered(address baseImpl, address upgradeImpl);

    /// @notice Emitted when an upgrade is unregistered by the Builder DAO
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    event UpgradeRemoved(address baseImpl, address upgradeImpl);

    /// @notice Event emitted when metadata renderer is updated.
    /// @param sender address of the updater
    /// @param renderer new metadata renderer address
    event MetadataRendererUpdated(address sender, address renderer);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if at least one founder is not provided upon deploy
    error FOUNDER_REQUIRED();

    /// @dev Reverts if caller is not the token owner
    error ONLY_TOKEN_OWNER();

    ///                                                          ///
    ///                            STRUCTS                       ///
    ///                                                          ///

    /// @notice The founder parameters
    /// @param wallet The wallet address
    /// @param ownershipPct The percent ownership of the token
    /// @param vestExpiry The timestamp that vesting expires
    struct FounderParams {
        address wallet;
        uint256 ownershipPct;
        uint256 vestExpiry;
    }

    /// @notice DAO Version Information information struct
    struct DAOVersionInfo {
        string token;
        string metadata;
        string auction;
        string treasury;
        string governor;
    }

    /// @notice The ERC-721 token parameters
    /// @param initStrings The encoded token name, symbol, collection description, collection image uri, renderer base uri
    /// @param metadataRenderer The metadata renderer implementation to use
    /// @param reservedUntilTokenId The tokenId that a DAO's auctions will start at
    struct TokenParams {
        bytes initStrings;
        address metadataRenderer;
        uint256 reservedUntilTokenId;
    }

    /// @notice The auction parameters
    /// @param reservePrice The reserve price of each auction
    /// @param duration The duration of each auction
    /// @param founderRewardRecipent The address to send founder rewards to
    /// @param founderRewardBps Percent of the auction bid in BPS to send to the founder recipent
    struct AuctionParams {
        uint256 reservePrice;
        uint256 duration;
        address founderRewardRecipent;
        uint16 founderRewardBps;
    }

    /// @notice The governance parameters
    /// @param timelockDelay The time delay to execute a queued transaction
    /// @param votingDelay The time delay to vote on a created proposal
    /// @param votingPeriod The time period to vote on a proposal
    /// @param proposalThresholdBps The basis points of the token supply required to create a proposal
    /// @param quorumThresholdBps The basis points of the token supply required to reach quorum
    /// @param vetoer The address authorized to veto proposals (address(0) if none desired)
    struct GovParams {
        uint256 timelockDelay;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThresholdBps;
        uint256 quorumThresholdBps;
        address vetoer;
    }

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice The token implementation address
    function tokenImpl() external view returns (address);

    /// @notice The metadata renderer implementation address
    function metadataImpl() external view returns (address);

    /// @notice The auction house implementation address
    function auctionImpl() external view returns (address);

    /// @notice The treasury implementation address
    function treasuryImpl() external view returns (address);

    /// @notice The governor implementation address
    function governorImpl() external view returns (address);

    /// @notice Deploys a DAO with custom token, auction, and governance settings
    /// @param founderParams The DAO founder(s)
    /// @param tokenParams The ERC-721 token settings
    /// @param auctionParams The auction settings
    /// @param govParams The governance settings
    function deploy(
        FounderParams[] calldata founderParams,
        TokenParams calldata tokenParams,
        AuctionParams calldata auctionParams,
        GovParams calldata govParams
    )
        external
        returns (
            address token,
            address metadataRenderer,
            address auction,
            address treasury,
            address governor
        );

    /// @notice A DAO's remaining contract addresses from its token address
    /// @param token The ERC-721 token address
    function getAddresses(address token)
        external
        returns (
            address metadataRenderer,
            address auction,
            address treasury,
            address governor
        );

    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function isRegisteredUpgrade(address baseImpl, address upgradeImpl) external view returns (bool);

    /// @notice Called by the Builder DAO to offer opt-in implementation upgrades for all other DAOs
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function registerUpgrade(address baseImpl, address upgradeImpl) external;

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function removeUpgrade(address baseImpl, address upgradeImpl) external;
}
