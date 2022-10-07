// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library ScoreUtils {
    function yesNoIncrement(uint256 score, uint256 yes, uint256 no)
        internal
        pure
        returns (uint256)
    {
        require(
            (yes == 0 || no == 0) && yes != no, "Cannot increment both Y&N"
        );

        (uint256 _yes, uint256 _no) = readYesNoScore(score);

        unchecked {
            _yes += yes;
            _no += no;
        }
        return storeYesNo(_yes, _no);
    }

    function storeYesNo(uint256 yes, uint256 no)
        internal
        pure
        returns (uint256)
    {
        return (yes << 128) | no;
    }

    function readYesNoScore(uint256 score)
        internal
        pure
        returns (uint256 yes, uint256 no)
    {
        yes = uint128(score >> 128);
        no = uint128(score);
    }
}