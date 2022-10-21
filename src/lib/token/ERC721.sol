// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IERC721 } from "../interfaces/IERC721.sol";
import { Initializable } from "../utils/Initializable.sol";
import { ERC721TokenReceiver } from "../utils/TokenReceiver.sol";
import { Address } from "../utils/Address.sol";

/// @title ERC721
/// @author Rohan Kulkarni
/// @notice Modified from OpenZeppelin Contracts v4.7.3 (token/ERC721/ERC721Upgradeable.sol)
/// - Uses custom errors declared in IERC721
abstract contract ERC721 is IERC721, Initializable {
    ///                                                          ///
    ///                            STORAGE                       ///
    ///                                                          ///

    /// @notice The token name
    string public name;

    /// @notice The token symbol
    string public symbol;

    /// @notice The token owners
    /// @dev ERC-721 token id => Owner
    mapping(uint256 => address) internal owners;

    /// @notice The owner balances
    /// @dev Owner => Balance
    mapping(address => uint256) internal balances;

    /// @notice The token approvals
    /// @dev ERC-721 token id => Manager
    mapping(uint256 => address) internal tokenApprovals;

    /// @notice The balance approvals
    /// @dev Owner => Operator => Approved
    mapping(address => mapping(address => bool)) internal operatorApprovals;

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @dev Initializes an ERC-721 token
    /// @param _name The ERC-721 token name
    /// @param _symbol The ERC-721 token symbol
    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
    }

    /// @notice The token URI
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {}

    /// @notice The contract URI
    function contractURI() public view virtual returns (string memory) {}

    /// @notice If the contract implements an interface
    /// @param _interfaceId The interface id
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID
            _interfaceId == 0x80ac58cd || // ERC721 Interface ID
            _interfaceId == 0x5b5e139f; // ERC721Metadata Interface ID
    }

    /// @notice The account approved to manage a token
    /// @param _tokenId The ERC-721 token id
    function getApproved(uint256 _tokenId) external view returns (address) {
        return tokenApprovals[_tokenId];
    }

    /// @notice If an operator is authorized to manage all of an owner's tokens
    /// @param _owner The owner address
    /// @param _operator The operator address
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    /// @notice The number of tokens owned
    /// @param _owner The owner address
    function balanceOf(address _owner) public view returns (uint256) {
        if (_owner == address(0)) revert ADDRESS_ZERO();

        return balances[_owner];
    }

    /// @notice The owner of a token
    /// @param _tokenId The ERC-721 token id
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = owners[_tokenId];

        if (owner == address(0)) revert INVALID_OWNER();

        return owner;
    }

    /// @notice Authorizes an account to manage a token
    /// @param _to The account address
    /// @param _tokenId The ERC-721 token id
    function approve(address _to, uint256 _tokenId) external {
        address owner = owners[_tokenId];

        if (msg.sender != owner && !operatorApprovals[owner][msg.sender]) revert INVALID_APPROVAL();

        tokenApprovals[_tokenId] = _to;

        emit Approval(owner, _to, _tokenId);
    }

    /// @notice Authorizes an account to manage all tokens
    /// @param _operator The account address
    /// @param _approved If permission is being given or removed
    function setApprovalForAll(address _operator, bool _approved) external {
        operatorApprovals[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice Transfers a token from sender to recipient
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        if (_from != owners[_tokenId]) revert INVALID_OWNER();

        if (_to == address(0)) revert ADDRESS_ZERO();

        if (msg.sender != _from && !operatorApprovals[_from][msg.sender] && msg.sender != tokenApprovals[_tokenId]) revert INVALID_APPROVAL();

        _beforeTokenTransfer(_from, _to, _tokenId);

        unchecked {
            --balances[_from];

            ++balances[_to];
        }

        owners[_tokenId] = _to;

        delete tokenApprovals[_tokenId];

        emit Transfer(_from, _to, _tokenId);

        _afterTokenTransfer(_from, _to, _tokenId);
    }

    /// @notice Safe transfers a token from sender to recipient
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        transferFrom(_from, _to, _tokenId);

        if (
            Address.isContract(_to) &&
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") != ERC721TokenReceiver.onERC721Received.selector
        ) revert INVALID_RECIPIENT();
    }

    /// @notice Safe transfers a token from sender to recipient with additional data
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external {
        transferFrom(_from, _to, _tokenId);

        if (
            Address.isContract(_to) &&
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) != ERC721TokenReceiver.onERC721Received.selector
        ) revert INVALID_RECIPIENT();
    }

    /// @dev Mints a token to a recipient
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function _mint(address _to, uint256 _tokenId) internal virtual {
        if (_to == address(0)) revert ADDRESS_ZERO();

        if (owners[_tokenId] != address(0)) revert ALREADY_MINTED();

        _beforeTokenTransfer(address(0), _to, _tokenId);

        unchecked {
            ++balances[_to];
        }

        owners[_tokenId] = _to;

        emit Transfer(address(0), _to, _tokenId);

        _afterTokenTransfer(address(0), _to, _tokenId);
    }

    /// @dev Burns a token to a recipient
    /// @param _tokenId The ERC-721 token id
    function _burn(uint256 _tokenId) internal virtual {
        address owner = owners[_tokenId];

        if (owner == address(0)) revert NOT_MINTED();

        _beforeTokenTransfer(owner, address(0), _tokenId);

        unchecked {
            --balances[owner];
        }

        delete owners[_tokenId];

        delete tokenApprovals[_tokenId];

        emit Transfer(owner, address(0), _tokenId);

        _afterTokenTransfer(owner, address(0), _tokenId);
    }

    /// @dev Hook called before a token transfer
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {}

    /// @dev Hook called after a token transfer
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _tokenId The ERC-721 token id
    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {}
}
