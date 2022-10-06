// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/helpers/ScoreUtils.sol";

contract Utils_test is Test {
    using ScorePackage for uint256;

    function setUp() public {}

    function testBytes() public {
        // store y/n score
        uint256 score;

        score = score.incrementYN(6, 0);

        emit log_uint(score.readYes());
    }

    function _join(uint256 yes, uint256 no)
        internal
        pure
        returns (uint256)
    {
        return (yes << 128) | no;
    }

    function _split(uint256 score)
        internal
        pure
        returns (uint128 yes, uint128 no)
    {
        yes = uint128(score >> 128);
        no = uint128(score);
    }

    function _incrementScore(uint256 score, uint128 yes, uint128 no)
        internal
        pure
        returns (uint256)
    {
        require((yes == 0 || no == 0) && yes != no, "Score: impossible");
        (uint128 _yes, uint128 _no) = _split(score);
        unchecked {
            _yes += yes;
            _no += no;
        }
        return _join(uint256(_yes), uint256(_no));
    }
}
