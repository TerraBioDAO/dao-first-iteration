// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library ScorePackage {
    function incrementYN(uint256 score, uint128 yes, uint128 no)
        internal
        pure
        returns (uint256)
    {
        require(
            (yes == 0 || no == 0) && yes != no, "Cannot increment both Y&N"
        );
        (uint128 _yes, uint128 _no) = _split(score);
        unchecked {
            _yes += yes;
            _no += no;
        }
        return _join(uint256(_yes), uint256(_no));
    }

    function readYes(uint256 score) internal pure returns (uint128 yes) {
        (yes,) = _split(score);
    }

    function readNo(uint256 score) internal pure returns (uint128 no) {
        (, no) = _split(score);
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
}
