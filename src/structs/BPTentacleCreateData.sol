// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBPTentacleHelper} from "../interfaces/IBPTentacleHelper.sol";

/// @custom:member id The ID of the tentacle being created.
/// @custom:member helper The helper to use for creating the tentacle.
struct BPTentacleCreateData {
    uint8 id;
    IBPTentacleHelper helper;
}
