// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IToken} from "./token/Token.sol";
import {IMetadataRenderer} from "./token/metadata/IMetadataRenderer.sol";
import {IAuction} from "./auction/Auction.sol";
import {ITreasury} from "./governance/treasury/Treasury.sol";
import {IGovernor} from "./governance/governor/Governor.sol";
import {IDeployer} from "./IDeployer.sol";

/// @title Nounish DAO Deployer
/// @author Rohan Kulkarni
/// @notice This contract deploys Nounish DAOs with custom token, auction, and governance settings
contract Deployer is IDeployer {
    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice The address of the token implementation
    address public immutable tokenImpl;

    /// @notice The hash of the token proxy bytecode
    bytes32 public immutable tokenHash;

    /// @notice The metadata renderer implementation
    address public immutable metadataImpl;

    /// @notice The hash of the metadata renderer proxy bytecode
    bytes32 public immutable metadataHash;

    /// @notice The auction house implementation
    address public immutable auctionImpl;

    /// @notice The hash of the auction proxy bytecode
    bytes32 public immutable auctionHash;

    /// @notice The treasury implementation
    address public immutable treasuryImpl;

    /// @notice The hash of the treasury proxy bytecode
    bytes32 public immutable treasuryHash;

    /// @notice The governor implementation
    address public immutable governorImpl;

    /// @notice The hash of the governor proxy bytecode
    bytes32 public immutable governorHash;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    constructor(
        address _tokenImpl,
        address _metadataImpl,
        address _auctionImpl,
        address _treasuryImpl,
        address _governorImpl
    ) {
        tokenImpl = _tokenImpl;
        tokenHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_tokenImpl, "")));

        metadataImpl = _metadataImpl;
        metadataHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_metadataImpl, "")));

        auctionImpl = _auctionImpl;
        auctionHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_auctionImpl, "")));

        treasuryImpl = _treasuryImpl;
        treasuryHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_treasuryImpl, "")));

        governorImpl = _governorImpl;
        governorHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_governorImpl, "")));
    }

    ///                                                          ///
    ///                             DEPLOY                       ///
    ///                                                          ///

    /// @notice The number of DAOs deployed
    uint256 public totalDeployed;

    /// @notice Emitted when a Nounish DAO is deployed
    /// @param token The address of the token
    /// @param metadata The address of the metadata renderer
    /// @param auction The address of the auction
    /// @param treasury The address of the treasury
    /// @param governor The address of the governor
    /// @param daoId The id of the DAO
    event DAODeployed(uint256 daoId, address token, address metadata, address auction, address treasury, address governor);

    /// @notice Deploys a Nounish DAO
    /// @param _tokenParams The initial token config
    /// @param _auctionParams The initial auction config
    /// @param _govParams The initial governance config
    function deploy(
        TokenParams calldata _tokenParams,
        AuctionParams calldata _auctionParams,
        GovParams calldata _govParams
    )
        public
        returns (
            address token,
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        uint256 daoId;

        unchecked {
            daoId = ++totalDeployed;
        }

        token = address(new ERC1967Proxy{salt: bytes32(daoId)}(tokenImpl, ""));
        metadata = address(new ERC1967Proxy{salt: bytes32(daoId)}(metadataImpl, ""));
        auction = address(new ERC1967Proxy{salt: bytes32(daoId)}(auctionImpl, ""));
        treasury = address(new ERC1967Proxy{salt: bytes32(daoId)}(treasuryImpl, ""));
        governor = address(new ERC1967Proxy{salt: bytes32(daoId)}(governorImpl, ""));

        IToken(token).initialize(
            _tokenParams.initStrings,
            metadata,
            _tokenParams.foundersDAO,
            _tokenParams.foundersMaxAllocation,
            _tokenParams.foundersAllocationFrequency,
            auction
        );

        IMetadataRenderer(metadata).initialize(_tokenParams.initStrings, token, _tokenParams.foundersDAO, treasury);

        IAuction(auction).initialize(token, _tokenParams.foundersDAO, treasury, _auctionParams.duration, _auctionParams.reservePrice);

        ITreasury(treasury).initialize(governor, _govParams.timelockDelay);

        IGovernor(governor).initialize(
            treasury,
            token,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBPS,
            _govParams.quorumVotesBPS
        );

        emit DAODeployed(daoId, token, metadata, auction, treasury, governor);
    }

    function getAddresses(uint256 _daoId)
        external
        view
        returns (
            address token,
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        token = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_daoId), tokenHash)))));
        metadata = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_daoId), metadataHash)))));
        auction = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_daoId), auctionHash)))));
        treasury = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_daoId), treasuryHash)))));
        governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_daoId), governorHash)))));
    }
}
