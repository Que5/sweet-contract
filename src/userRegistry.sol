//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserRegistry {
    // State variables and data structures
    
    mapping(address => bool) public registeredUsers;
    address[] public userAddresses;
    
    // Event emitted when a new user is registered
    event UserRegistered(address indexed user);
    
    // Function to register a new user
    function registerUser(address user) external {
        require(!registeredUsers[user], "User already registered");
        
        registeredUsers[user] = true;
        userAddresses.push(user);
        
        emit UserRegistered(user);
    }
    
    // Function to get the user address at a specific index
    function getUserAddressByIndex(uint256 index) external view returns (address) {
        require(index < userAddresses.length, "Invalid index");
        
        return userAddresses[index];
    }
    

}