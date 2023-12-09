// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


contract ContractRegistry is Ownable {
    mapping(string => address) private contracts;

    constructor(address _owner) Ownable(_owner) {}

    function getContractAddress(string memory name)
        public
        view
        returns (address)
    {
        return contracts[name];
    }

    function setContractAddress(string memory name, address addr)
        public
        onlyOwner
    {
        contracts[name] = addr;
    }
}
