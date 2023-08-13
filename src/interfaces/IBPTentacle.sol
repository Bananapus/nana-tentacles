// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IBPTentacle {
    
    /**
     * @notice
     * Mint tokens to a user.
     * 
     * @param _to the address to receive the minted tokens
     * @param _amount the amount of tokens to mint to the address
     */
    function mint(
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice
     * Burns tokens from a user.
     * 
     * @dev should revert if the user does not have the needed balance
     * 
     * @param _caller the caller that is attempting to burn tokens from the account
     * @param _from the address that will burn tokens
     * @param _amount the amount of tokens that will get burned
     */
    function burn(
        address _caller,
        address _from,
        uint256 _amount
    ) external;
}