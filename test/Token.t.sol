// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { NounsBuilderTest } from "./utils/NounsBuilderTest.sol";

contract TokenTest is NounsBuilderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Init() public {
        deploy();

        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.auction(), address(auction));
        assertEq(token.owner(), founder);
        assertEq(address(token.metadataRenderer()), address(metadataRenderer));
    }

    // should mint token 0 to founder 0

    // should mint the next token to the auction house

    // should revert if anyone tries calling the auction house that isn't the auction house itself

    // should return the token uri and contract uri generated in the metadata renderer

    /** should handle all vesting scenarios
     */

    /** should handle all token gov
        
        delegateBySig
        - reverts if invalid sig
        - reverts if bad nonce
        - reverts if sig expired

        checkpoints
        - returns number of checkpoints for a delegate
        - ? does not add more than one checkpoint in a block? -- CHECK IT OUT BUT PROB DON'T NEED
        - ensure checkpoints are added + subtracted correctly

        getPastVotes
        - reverts if given timestamp > current timestamp 
        - returns 0 if no checkpoints
        - returns voting balance at timestamp
        - never delegates to address(0)
    
     */
}
