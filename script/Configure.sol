// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "./ConfigureOPTentacle.sol";
import "src/BPLockManager.sol";

contract ConfigureManagerScript is ConfigureOPTentacleScript {
    string L1_RPC = "https://gateway.tenderly.co/public/goerli";
    address owner = address(0x1337);
    IStakingDelegate L1_STAKING_DELEGATE = IStakingDelegate(0x3281688433Be4409A1E64bD604605a57328db416);

    // OPL1StandardBridge L1_BRIDGE;

    function setUp() public {
        // L1_STAKING_DELEGATE = IStakingDelegate(address(0));

        // L1_RPC = "https://gateway.tenderly.co/public/goerli";
        // L1_TENTACLE_TOKEN = address(1);
        // L1_BRIDGE = OPL1StandardBridge(0x636Af16bf2f682dD3109e60102b8E1A089FedAa8); // 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1

        // L2_RPC = "https://optimism-goerli.gateway.tenderly.co";
        // L2_FACTORY = OptimismMintableERC20Factory(0x4200000000000000000000000000000000000012);
        // L2_TOKEN_NAME = "Optimistic Bananapus";
        // L2_TOKEN_SYMBOL = "OPNANA";
    }

    function run() public {
        //
        uint256 _L1Fork = vm.createSelectFork(L1_RPC);
        vm.broadcast();
        BPLockManager _lockManager = new BPLockManager(L1_STAKING_DELEGATE, owner);

        // Deploy for Optimism
        (IBPTentacle _opTentacle, OptimismTentacleHelper _opHelper) = _preconfigureOptimisticL2(
            _L1Fork,
            OPL1StandardBridge(0x636Af16bf2f682dD3109e60102b8E1A089FedAa8),
            _lockManager,
            "https://optimism-goerli.gateway.tenderly.co",
            OptimismMintableERC20Factory(0x4200000000000000000000000000000000000012),
            "Optimistic Bananapus",
            "OP-NANA"
        );

        // Deploy for BASE
        (IBPTentacle _baseTentacle, OptimismTentacleHelper _baseHelper) = _preconfigureOptimisticL2(
            _L1Fork,
            OPL1StandardBridge(0xfA6D8Ee5BE770F84FC001D098C4bD604Fe01284a),
            _lockManager,
            "https://base-goerli.gateway.tenderly.co",
            OptimismMintableERC20Factory(0x4200000000000000000000000000000000000012),
            "Base Bananapus",
            "BA-NANA"
        );

        // Configure for Optimism
        vm.selectFork(_L1Fork);
        vm.broadcast();
        _lockManager.setTentacle(
            1,
            BPTentacleConfiguration({
                hasDefaultHelper: false,
                forceDefault: false,
                revertIfDefaultForcedAndOverriden: false,
                mintRequiresNativeAssetPayment: false,
                tentacle: _opTentacle
            }),
            _opHelper
        );

        // Configure for Base
        vm.broadcast();
        _lockManager.setTentacle(
            2,
            BPTentacleConfiguration({
                hasDefaultHelper: false,
                forceDefault: false,
                revertIfDefaultForcedAndOverriden: false,
                mintRequiresNativeAssetPayment: false,
                tentacle: _baseTentacle
            }),
            _baseHelper
        );

        console2.log("Helper for OP is ", address(_opHelper));
        console2.log("Helper for BASE is ", address(_baseHelper));
        console2.log("L1 Lockmanager is ", address(_lockManager));
    }
}
