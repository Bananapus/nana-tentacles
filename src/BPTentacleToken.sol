// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IBPTentacle} from "./interfaces/IBPTentacle.sol";

/// @notice A standard tentacle token.
contract BPTentacleToken is ERC20, ERC165, IBPTentacle {
    error UNAUTHORIZED();

    /// @notice The lock manager that has exlusive access to mint and burn this token.
    address immutable lockManager;

    /// @param _name The name of the token.
    /// @param _symbol The symbol of this token.
    /// @param _decimals The number of decimals to expect in this token's fixed point accounting.
    /// @param _lockManager The address that manages minting and burning this token.
    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _lockManager)
        ERC20(_name, _symbol, _decimals)
    {
        lockManager = _lockManager;
    }

    /// @notice Mints this token.
    /// @param _to The address that should receive the newly minted token.
    /// @param _amount The amount to mint.
    function mint(address _to, uint256 _amount) external {
        // Make sure only the lock manager can mint.
        if (msg.sender != lockManager) revert UNAUTHORIZED();

        _mint(_to, _amount);
    }

    /// @notice Burns this token.
    /// @param _from The address that the tokens should be burned from.
    /// @param _amount The amount to burn.
    function burn(address, address _from, uint256 _amount) external override {
        // Make sure only the lock manager can burn.
        if (msg.sender != lockManager) revert UNAUTHORIZED();

        _burn(_from, _amount);
    }
}
