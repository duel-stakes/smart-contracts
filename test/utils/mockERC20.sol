//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract mockERC20 is ERC20 {
    constructor() ERC20("Payment","tkn"){
        _mint(msg.sender, 10 ether);
    }

    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }
    function mint(uint256 _amount, address _user) external {
        _mint(_user, _amount);
    }
}