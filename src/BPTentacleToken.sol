// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/tokens/ERC20.sol";
import "src/interfaces/IBPTentacle.sol";

contract BPTentacleToken is ERC20, IBPTentacle {
    error NOT_LOCK_MANAGER();

    address immutable lockManager;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _lockManager
    ) ERC20(_name, _symbol, _decimals) {
        lockManager = _lockManager;
    }

    function mint(address _to, uint256 _amount) external {
        if (msg.sender != lockManager) revert NOT_LOCK_MANAGER();
        _mint(_to, _amount);
    }

    function burn(
        address ,
        address _from,
        uint256 _amount
    ) external override {
        if (msg.sender != lockManager) revert NOT_LOCK_MANAGER();
        _burn(_from, _amount);
    }
}