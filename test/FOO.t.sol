// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/test.sol";

// contract Init {
//     uint8 internal _initialized;

//     error NOT_INITIALIZING();

//     /// @dev `bytes4(keccak256(bytes("Unauthorized()")))`
//     uint256 private constant ERROR = bytes4(keccak256(bytes("NOT_INITIALIZING()")));

//     modifier onlyInit() {
//         assembly {
//             if iszero(sload(_initialized.slot)) {
//                 mstore(0x00, ERROR)
//             }
//         }
//     }
// }

// contract Foo {
//     struct Founder {
//         address addr;
//         uint8 pct;
//     }

//     Founder[] public founders;

//     function storeFounders(Founder[] calldata _founders) public {
//         for (uint256 i; i < _founders.length; i++) {
//             founders.push();

//             founders[i] = _founders[i];
//         }
//     }

//     // function _store(Founder[] memory _founders) internal {
//     //     founders = _founders;
//     // }
// }

// contract FooTest is Test {
//     Foo.Founder[] internal testFounders;

//     function setUp() public {
//         testFounders.push();

//         testFounders[0] = Foo.Founder({addr: address(this), pct: 5});

//         testFounders.push();

//         testFounders[1] = Foo.Founder({addr: address(this), pct: 10});
//     }

//     uint256 a;
//     uint256 b;
//     uint256 result;

//     function testFoo() public {
//         a = 10;
//         b = 100;

//         result = a / b;

//         emit log_uint(result);
//     }
// }

// contract Foo {
//     struct Founder {
//         address addr;
//         uint8 pct;
//         uint64 cap;
//     }

//     Founder[] public founders;

//     function store(Founder[] calldata _founders) public {
//         uint256 numFounders = _founders.length;

//         uint256 mcd = computeMCD(numFounders, _founders);
//     }

//     // O(n^2)
//     function computeMCD(uint256 _numFounders, Founder[] calldata _founders) public returns (uint256 mcd) {
//         unchecked {
//             for (uint256 i = 100; i > 0; --i) {
//                 bool found = true;

//                 for (uint256 k; k < _numFounders; ++k) {
//                     if (found && i % _founders[k].pct == 0) {
//                         continue;
//                     } else {
//                         found = false;
//                         break;
//                     }
//                 }

//                 if (found) return i;
//             }

//             return 0;
//         }
//     }

//     address[] public ALLOCATION;

//     function store(uint256 _MCD, Founder[] calldata _founders) public {
//         ALLOCATION = new address[](_MCD);

//         uint256 ALLOCATION_INDEX = 0;

//         for (uint256 i; i < _founders.length; ++i) {
//             uint256 mod = _MCD / _founders[i].pct;

//             for (uint256 k; k < mod; ++k) {
//                 ALLOCATION[ALLOCATION_INDEX] = _founders[i].addr;

//                 ALLOCATION_INDEX += mod;
//             }
//         }
//     }

//     uint256 public totalSupply;

//     // function mint() public {
//     //     if ()
//     // }
// }

// contract FooTest is Test {
//     Foo internal foo;

//     Foo.Founder[] internal testFounders;

//     function setUp() public {
//         foo = new Foo();

//         testFounders.push();
//         testFounders.push();

//         testFounders[0] = Foo.Founder({addr: address(this), pct: 7, cap: 5 hours});
//         testFounders[1] = Foo.Founder({addr: address(this), pct: 10, cap: 5 hours});
//     }

//     function testMCD() public {
//         uint256 mcd = foo.computeMCD(2, testFounders);

//         emit log_uint(mcd);
//     }
// }
