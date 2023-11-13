// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBPTentacle {
    function mint(address to, uint256 amount) external payable;
    function burn(address caller, address from, uint256 amount) external;
}
