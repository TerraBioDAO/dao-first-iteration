// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/helpers/ScoreUtils.sol";

contract ScoreUtilsTest is Test {

    using ScoreUtils for uint256;
    uint256 score;

    function setUp() public {
        score = 0;
    }

    function testIncrementYesAndNo() public {
        score = score.yesNoIncrement(1, 0);
        score = score.yesNoIncrement(3, 0);
        score = score.yesNoIncrement(0, 2);
        score = score.yesNoIncrement(0, 1);
        (uint256 _yes, uint256 _no) = ScoreUtils.readYesNoScore(score);
        assertEq(_yes, 4);
        assertEq(_no, 3);
    }

    function testIncrementYesAndNo_fuzz(uint128 vote) public {
        if (vote != 0) {
            score = score.yesNoIncrement(vote, 0);
            score = score.yesNoIncrement(0, vote);
            console.log(score);
            (uint256 _yes, uint256 _no) = ScoreUtils.readYesNoScore(score);
            assertEq(_yes, vote);
            assertEq(_no, vote);
        }
    }

    function testIncrementYesAndNo_ko() public {
        vm.expectRevert("Cannot increment both Y&N");
        score = score.yesNoIncrement(0, 0);
    }

    function testIncrementYesAndNo_ko2() public {
        vm.expectRevert("Cannot increment both Y&N");
        score = score.yesNoIncrement(1, 2);
    }
}
