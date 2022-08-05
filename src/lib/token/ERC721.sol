// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Initializable} from "../proxy/Initializable.sol";
import {Address} from "../utils/Address.sol";
import {Strings} from "../utils/Strings.sol";
import {ERC721TokenReceiver} from "../utils/TokenReceiver.sol";

contract ERC721StorageV1 {
    string public name;

    string public symbol;

    uint256 public totalSupply;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;
}

abstract contract ERC721 is Initializable, ERC721StorageV1 {
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
    }

    function tokenURI(uint256 _tokenId) public view virtual returns (string memory) {}

    function contractURI() public view virtual returns (string memory) {}

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID
            interfaceId == 0x80ac58cd || // ERC721 Interface ID
            interfaceId == 0x5b5e139f; // ERC721Metadata Interface ID
    }

    function balanceOf(address _owner) public view virtual returns (uint256) {
        require(_owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[_owner];
    }

    function ownerOf(uint256 _tokenId) public view virtual returns (address) {
        address owner = _ownerOf[_tokenId];

        require(owner != address(0), "ZERO_ADDRESS");

        return owner;
    }

    function approve(address _to, uint256 _tokenId) public virtual {
        address owner = _ownerOf[_tokenId];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[_tokenId] = _to;

        emit Approval(owner, _to, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) public virtual {
        isApprovedForAll[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual {
        require(_from == _ownerOf[_tokenId], "WRONG_FROM");

        require(_to != address(0), "INVALID_RECIPIENT");

        require(msg.sender == _from || isApprovedForAll[_from][msg.sender] || msg.sender == getApproved[_tokenId], "NOT_AUTHORIZED");

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
    ) public virtual {
        transferFrom(_from, _to, _tokenId);

        require(
            !Address.isContract(_to) ||
                ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) public virtual {
        transferFrom(_from, _to, _tokenId);

        require(
            !Address.isContract(_to) ||
                ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _mint(address _to, uint256 _tokenId) internal virtual returns (uint256) {
        require(_to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[_tokenId] == address(0), "ALREADY_MINTED");

        _beforeTokenTransfer(address(0), _to, _tokenId);

        unchecked {
            ++totalSupply;
            ++_balanceOf[_to];
        }

        _ownerOf[_tokenId] = _to;

        emit Transfer(address(0), _to, _tokenId);

        _afterTokenTransfer(address(0), _to, _tokenId);

        return totalSupply;
    }

    function _burn(uint256 _tokenId) internal virtual {
        address owner = _ownerOf[_tokenId];

        require(owner != address(0), "NOT_MINTED");

        _beforeTokenTransfer(owner, address(0), _tokenId);

        unchecked {
            --totalSupply;
            --_balanceOf[owner];
        }

        delete _ownerOf[_tokenId];

        delete getApproved[_tokenId];

        emit Transfer(owner, address(0), _tokenId);

        _afterTokenTransfer(owner, address(0), _tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
