// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract zLendToken is ERC20 {
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        console.log('Starting depl');
        _mint(msg.sender, 1000000000 ether);
        _mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 10000 ether);
        _mint(0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199, 10000  ether); 
        _mint(0x5A2770f69AF30370D60B416ad31FF538839112F6, 13000  ether);
    }
}