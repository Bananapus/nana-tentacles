// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {OptimismTentacleHelper, OPL1StandardBridge, ERC20, IBPTentacle} from "src/tentacleHelpers/OptimismTentacleHelper.sol";
import {BPTentacleToken} from "src/BPTentacleToken.sol";

contract ConfigureOPScript is Script {

    string L1_RPC;
    OPL1StandardBridge L1_BRIDGE;
    address L1_TENTACLE_TOKEN;
    address L1_LOCK_MANAGER;
   
    string L2_RPC;
    OptimismMintableERC20Factory L2_FACTORY;
    string L2_TOKEN_NAME;
    string L2_TOKEN_SYMBOL;

    function setUp() public {
        L1_RPC = "https://gateway.tenderly.co/public/goerli";
        L1_TENTACLE_TOKEN = address(1);
        L1_BRIDGE = OPL1StandardBridge(0x636Af16bf2f682dD3109e60102b8E1A089FedAa8); // 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1

        L2_RPC = "https://optimism-goerli.gateway.tenderly.co";
        L2_FACTORY = OptimismMintableERC20Factory(0x4200000000000000000000000000000000000012);
        L2_TOKEN_NAME = "Optimistic Bananapus";
        L2_TOKEN_SYMBOL = "OPNANA";

        L1_LOCK_MANAGER = address(msg.sender);
    }

    function run() public {
        // 
        uint256 _L1Fork = vm.createSelectFork(L1_RPC);
        vm.startBroadcast();
        BPTentacleToken _token = new BPTentacleToken(L2_TOKEN_NAME, L2_TOKEN_SYMBOL, 18, L1_LOCK_MANAGER);
        L1_TENTACLE_TOKEN = address(_token);
        vm.stopBroadcast();

        // Perform the L2 steps
        vm.createSelectFork(L2_RPC);
        vm.startBroadcast();
        address L2_TOKEN = L2_FACTORY.createOptimismMintableERC20(
            L1_TENTACLE_TOKEN,
            L2_TOKEN_NAME,
            L2_TOKEN_SYMBOL
        );
        vm.stopBroadcast();

        // Perform the L1 steps
        vm.selectFork(_L1Fork);
        vm.startBroadcast();
        /* OptimismTentacleHelper _helper = */ new OptimismTentacleHelper(
            ERC20(L1_TENTACLE_TOKEN),
            L2_TOKEN,
            L1_BRIDGE
        );

        // // Perform test L1 -> L2
        // _token.mint(address(_helper), 500 ether);
        // _helper.createFor(
        //     0, 
        //     IBPTentacle(address(0)),
        //     0,
        //     500 ether,
        //     address(msg.sender)
        // );
        vm.stopBroadcast();
    }
}


interface OptimismMintableERC20Factory {
    function createOptimismMintableERC20(
        address _remoteToken,
        string memory _name,
        string memory _symbol
    ) external returns (address);
}