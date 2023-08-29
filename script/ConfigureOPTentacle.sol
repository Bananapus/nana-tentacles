// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {OptimismTentacleHelper, OPL1StandardBridge, ERC20, IBPTentacle} from "src/tentacleHelpers/OptimismTentacleHelper.sol";
import {BPTentacleToken} from "src/BPTentacleToken.sol";
import "src/BPLockManager.sol";

abstract contract ConfigureOPTentacleScript is Script {

    /**
     * 
     * @param _FORGE_L1_FORK The number that represents the fork that is L1
     * @param _L1_BRIDGE The L1 OP standard bridge
     * @param _L1_LOCK_MANAGER The L1 Bananapus lockManager
     * @param _L2_RPC The RPC to use for L2 transactions
     * @param _L2_FACTORY The L2 OptimismMintableERC20Factory
     * @param _L2_TOKEN_NAME The token name for the L2 token
     * @param _L2_TOKEN_SYMBOL The token symbol for the L2 token
     * @return The tentacle to configure on the LockManager
     * @return The helper that is able to perform he L1 -> L2 bridging
     */
    function _preconfigureOptimisticL2 (
        uint256 _FORGE_L1_FORK,
        OPL1StandardBridge _L1_BRIDGE,
        BPLockManager _L1_LOCK_MANAGER,

        string memory _L2_RPC,
        OptimismMintableERC20Factory _L2_FACTORY,
        string memory _L2_TOKEN_NAME,
        string memory _L2_TOKEN_SYMBOL
    ) internal returns(
        IBPTentacle,
        OptimismTentacleHelper
    ) {
        // Perform the initial configuration on L1
        vm.selectFork(_FORGE_L1_FORK);
        vm.startBroadcast();
        BPTentacleToken _token = new BPTentacleToken(_L2_TOKEN_NAME, _L2_TOKEN_SYMBOL, 18, address(_L1_LOCK_MANAGER));
        address _L1_TENTACLE_TOKEN = address(_token);
        vm.stopBroadcast();

        // Perform the initial configuration on L2
        vm.createSelectFork(_L2_RPC);
        vm.startBroadcast();
        address _L2_TOKEN = _L2_FACTORY.createOptimismMintableERC20(
            _L1_TENTACLE_TOKEN,
            _L2_TOKEN_NAME,
            _L2_TOKEN_SYMBOL
        );
        vm.stopBroadcast();

        // Perform the final pre-configuration steps on L1 that links the L1 and L2 deployments
        vm.selectFork(_FORGE_L1_FORK);
        vm.startBroadcast();
        OptimismTentacleHelper _helper = new OptimismTentacleHelper(
            ERC20(_L1_TENTACLE_TOKEN),
            _L2_TOKEN,
            _L1_BRIDGE
        ); 
        vm.stopBroadcast();

        return (_token, _helper);
    }
}


interface OptimismMintableERC20Factory {
    function createOptimismMintableERC20(
        address _remoteToken,
        string memory _name,
        string memory _symbol
    ) external returns (address);
}