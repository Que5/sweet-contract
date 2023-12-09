// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract cZAR is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    address public dexAddress;

    constructor() ERC20("cZAR", "CZAR") Ownable(msg.sender) {
        uint256 initialSupply = 2500 * (10**decimals());
        _mint(msg.sender, initialSupply);
    }

    function setDEXAddress(address _dexAddress) external onlyOwner {
        dexAddress = _dexAddress;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function safeTransfer(address to, uint256 amount) external onlyOwner {
        IERC20(address(this)).safeTransfer(to, amount);
    }
}
