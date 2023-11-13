// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBPLockManager} from "./IBPLockManager.sol";
import {IBPTentacle} from "./IBPTentacle.sol";

interface IBPTentacleHelper {
    function createFor(
        uint8 tentacleId,
        IBPTentacle tentacle,
        uint256[] memory tokenIds,
        uint256 amount,
        address beneficiary
    ) external payable;
}
