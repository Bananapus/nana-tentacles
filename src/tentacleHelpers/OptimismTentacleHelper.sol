// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBPTentacleHelper, IBPTentacle} from "src/interfaces/IBPTentacleHelper.sol";
import "lib/solmate/src/tokens/ERC20.sol";

contract OptimismTentacleHelper is IBPTentacleHelper {
    ERC20 immutable l1TokenAddress;

    /**
     * @dev this is the address of the token on L2, this is an address since it should never be called as a token on L1
     */
    address immutable l2TokenAddress;

    uint32 constant l2MinGasLimit = 100_000;

    OPL1StandardBridge immutable bridge;

    constructor(ERC20 _l1TokenAddress, address _l2TokenAddress, OPL1StandardBridge _bridge) {
        l1TokenAddress = _l1TokenAddress;
        l2TokenAddress = _l2TokenAddress;
        bridge = _bridge;

        // Give infinite approval, safes having to do an approval every time
        // this contract should never have any balance so this is safe to do
        _l1TokenAddress.approve(address(_bridge), type(uint256).max);
    }

    function createFor(uint8, IBPTentacle, uint256[] memory, uint256 _amount, address _beneficiary) external override {
        bridge.depositERC20To(address(l1TokenAddress), l2TokenAddress, _beneficiary, _amount, l2MinGasLimit, bytes(""));
    }
}

interface OPL1StandardBridge {
    /**
     * @custom:legacy
     * @notice Deposits some amount of ERC20 tokens into a target account on L2.
     *
     * @param _l1Token     Address of the L1 token being deposited.
     * @param _l2Token     Address of the corresponding token on L2.
     * @param _to          Address of the recipient on L2.
     * @param _amount      Amount of the ERC20 to deposit.
     * @param _minGasLimit Minimum gas limit for the deposit message on L2.
     * @param _extraData   Optional data to forward to L2. Data supplied here will not be used to
     *                     execute any code on L2 and is only emitted as extra data for the
     *                     convenience of off-chain tooling.
     */
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}
