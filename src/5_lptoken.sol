// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address private dex;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor(address _dex) ERC20("Liquidity Provider Token", "LPT") {
        dex = _dex;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == dex, "Only DEX can mint");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) public {
        require(msg.sender == dex, "Only DEX can burn");
        _burn(from, amount);
        emit Burned(from, amount);
    }
}
