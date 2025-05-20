// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomToken is ERC20 {
    address public issuer; 
    uint256 public requestId;

    constructor(
        string memory name, 
        string memory symbol, 
        uint256 totalSupply, 
        address _issuer, 
        uint256 _requestId
    ) 
        ERC20(name, symbol) 
    {
        issuer = _issuer;
        requestId = _requestId;
    }

    // Function modified to allow minting
    function mint(address to, uint256 amount) external {
        require(msg.sender == issuer || msg.sender == address(this), "Only issuer or contract can mint");
        _mint(to, amount);
    }

    // Override the transfer function
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(amount >= 1 * 10 ** decimals(), "Minimum transfer amount is 1 token");
        return super.transfer(recipient, amount);
    }

    // Override the transferFrom function
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(amount >= 1 * 10 ** decimals(), "Minimum transfer amount is 1 token");
        return super.transferFrom(sender, recipient, amount);
    }
}
