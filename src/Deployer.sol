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

    /// @notice The address of the metadata renderer implementation
    address public immutable metadataImpl;

    /// @notice The address of the auction house implementation
    address private immutable auctionImpl;

    /// @notice The address of the treasury implementation
    address public immutable treasuryImpl;

    /// @notice The address of the governor implementation
    address public immutable governorImpl;

    /// @notice The hash of the metadata renderer proxy bytecode
    bytes32 private immutable metadataHash;

    /// @notice The hash of the auction proxy bytecode
    bytes32 private immutable auctionHash;

    /// @notice The hash of the treasury proxy bytecode
    bytes32 private immutable treasuryHash;

    /// @notice The hash of the governor proxy bytecode
    bytes32 private immutable governorHash;

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
        metadataImpl = _metadataImpl;
        auctionImpl = _auctionImpl;
        treasuryImpl = _treasuryImpl;
        governorImpl = _governorImpl;

        metadataHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_metadataImpl, "")));
        auctionHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_auctionImpl, "")));
        treasuryHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_treasuryImpl, "")));
        governorHash = keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_governorImpl, "")));
    }

    ///                                                          ///
    ///                             DEPLOY                       ///
    ///                                                          ///

    /// @notice Emitted when a Nounish DAO is deployed
    /// @param token The address of the token
    /// @param metadata The address of the metadata renderer
    /// @param auction The address of the auction
    /// @param treasury The address of the treasury
    /// @param governor The address of the governor
    event DAODeployed(address token, address metadata, address auction, address treasury, address governor);

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
        require(_tokenParams.foundersAlloc.length > 0 && _tokenParams.foundersAlloc[0] != address(0), "must have founder allocation");
        token = address(new ERC1967Proxy(tokenImpl, ""));

        bytes32 salt = bytes32(uint256(uint160(token)));

        metadata = address(new ERC1967Proxy{salt: salt}(metadataImpl, ""));
        auction = address(new ERC1967Proxy{salt: salt}(auctionImpl, ""));
        treasury = address(new ERC1967Proxy{salt: salt}(treasuryImpl, ""));
        governor = address(new ERC1967Proxy{salt: salt}(governorImpl, ""));

        IToken(token).initialize(_tokenParams.initStrings, metadata, _tokenParams.foundersAlloc, auction);

        IMetadataRenderer(metadata).initialize(_tokenParams.initStrings, token, treasury);

        IAuction(auction).initialize(token, treasury, _tokenParams.foundersAlloc[0], _auctionParams.duration, _auctionParams.reservePrice);

        ITreasury(treasury).initialize(governor, _govParams.timelockDelay);

        IGovernor(governor).initialize(
            treasury,
            token,
            _govParams.votingDelay,
            _govParams.votingPeriod,
            _govParams.proposalThresholdBPS,
            _govParams.quorumVotesBPS
        );

        emit DAODeployed(token, metadata, auction, treasury, governor);
    }

    function getAddresses(address _token)
        external
        view
        returns (
            address metadata,
            address auction,
            address treasury,
            address governor
        )
    {
        bytes32 salt = bytes32(uint256(uint160(_token)));

        metadata = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, metadataHash)))));
        auction = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, auctionHash)))));
        treasury = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, treasuryHash)))));
        governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, governorHash)))));
    }
}
