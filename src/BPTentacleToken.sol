// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/tokens/ERC20.sol";

contract BPTentacleToken is ERC20 {
    error NOT_LOCK_MANAGER();

    address immutable lockManager;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {
        lockManager = msg.sender;
    }

    function mint(address _to, uint256 _amount) external {
        if(msg.sender != lockManager) revert NOT_LOCK_MANAGER();
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        if(msg.sender != lockManager) revert NOT_LOCK_MANAGER();
        _burn(_from, _amount);
    }
}