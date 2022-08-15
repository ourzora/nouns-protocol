// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";
import {Address} from "../utils/Address.sol";
import {Strings} from "../utils/Strings.sol";
import {ERC721TokenReceiver} from "../utils/TokenReceiver.sol";

contract ERC721StorageV1 {
    string public name;

    string public symbol;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;
}

abstract contract ERC721 is Initializable, ERC721StorageV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    error INVALID_ADDRESS();

    error NO_OWNER();

    error NOT_AUTHORIZED();

    error WRONG_OWNER();

    error INVALID_RECIPIENT();

    error ALREADY_MINTED();

    error NOT_MINTED();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {}

    function contractURI() public view virtual returns (string memory) {}

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {}

    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {}

    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
    }

    function supportsInterface(bytes4 _interfaceId) public pure returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID
            _interfaceId == 0x80ac58cd || // ERC721 Interface ID
            _interfaceId == 0x5b5e139f; // ERC721Metadata Interface ID
    }

    function balanceOf(address _owner) public view returns (uint256) {
        if (_owner == address(0)) revert INVALID_ADDRESS();

        return _balanceOf[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = _ownerOf[_tokenId];

        if (owner == address(0)) revert NO_OWNER();

        return owner;
    }

    function approve(address _to, uint256 _tokenId) public {
        address owner = _ownerOf[_tokenId];

        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NOT_AUTHORIZED();

        getApproved[_tokenId] = _to;

        emit Approval(owner, _to, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) public {
        isApprovedForAll[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        if (_from != _ownerOf[_tokenId]) revert WRONG_OWNER();

        if (_to == address(0)) revert INVALID_RECIPIENT();

        if (msg.sender != _from && !isApprovedForAll[_from][msg.sender] && msg.sender != getApproved[_tokenId]) revert NOT_AUTHORIZED();

        _beforeTokenTransfer(_from, _to, _tokenId);

        unchecked {
            --_balanceOf[_from];

            ++_balanceOf[_to];
        }

        _ownerOf[_tokenId] = _to;

        delete getApproved[_tokenId];

        emit Transfer(_from, _to, _tokenId);

        _afterTokenTransfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        transferFrom(_from, _to, _tokenId);

        if (
            Address.isContract(_to) &&
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") != ERC721TokenReceiver.onERC721Received.selector
        ) revert INVALID_RECIPIENT();
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) public {
        transferFrom(_from, _to, _tokenId);

        if (
            Address.isContract(_to) &&
            ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) != ERC721TokenReceiver.onERC721Received.selector
        ) revert INVALID_RECIPIENT();
    }

    function _mint(address _to, uint256 _tokenId) internal virtual {
        if (_to == address(0)) revert INVALID_RECIPIENT();

        if (_ownerOf[_tokenId] != address(0)) revert ALREADY_MINTED();

        _beforeTokenTransfer(address(0), _to, _tokenId);

        unchecked {
            ++_balanceOf[_to];
        }

        _ownerOf[_tokenId] = _to;

        emit Transfer(address(0), _to, _tokenId);

        _afterTokenTransfer(address(0), _to, _tokenId);
    }

    function _burn(uint256 _tokenId) internal virtual {
        address owner = _ownerOf[_tokenId];

        if (owner == address(0)) revert NOT_MINTED();

        _beforeTokenTransfer(owner, address(0), _tokenId);

        unchecked {
            --_balanceOf[owner];
        }

        delete _ownerOf[_tokenId];

        delete getApproved[_tokenId];

        emit Transfer(owner, address(0), _tokenId);

        _afterTokenTransfer(owner, address(0), _tokenId);
    }
}
