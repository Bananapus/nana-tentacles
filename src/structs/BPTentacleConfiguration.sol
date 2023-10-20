// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBPTentacle} from "../interfaces/IBPTentacle.sol";

/// @custom:member hasDefaultHelper Defines if a default helper is set (saves us an sload to check).
/// @custom:member forceDefault Defines if a default helper is set (saves us an sload to check).
/// @custom:member revertIfDefaultForcedAndOverriden If a forced default is set and the user provides an override, should this cause a revert, or should we not revert and use the forced default.
/// @custom:member tentacle The tentacle address.
struct BPTentacleConfiguration {
    bool hasDefaultHelper;
    bool forceDefault;
    bool revertIfDefaultForcedAndOverriden;
    IBPTentacle tentacle;
}