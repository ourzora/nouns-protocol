// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {ITokenSpec} from "./ITokenSpec.sol";

interface IToken is ITokenSpec, IERC721Upgradeable, IVotesUpgradeable {}
