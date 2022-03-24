// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract YieldToken is Ownable, ERC20("PaperV2", "PAPER") {
	using SafeMath for uint256;

    address public staking;

	constructor(address _staking) {
        staking = _staking;
	}

    function mint(address user, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == staking, "not owner or staking");
        _mint(user, amount);
    }
	
    function burn(uint256 amount) external {
        transferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, amount);
    }

	function setStaking(address _staking) external onlyOwner {
	    staking = _staking;
	}
}
