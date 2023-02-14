// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library Eventer {
    event Hey(string message);

    function sayHey() internal {
        emit Hey("Hello fame!");
    }
}
