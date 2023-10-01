// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IBPLockManager} from "./IBPLockManager.sol";
import {IBPTentacle} from "./IBPTentacle.sol";

interface IBPTentacleHelper {
    function createFor(
        uint8 _tentacleId,
        IBPTentacle _tentacle,
        uint256 _tokenId,
        uint256 _amount,
        address _beneficiary
    ) external;
}
