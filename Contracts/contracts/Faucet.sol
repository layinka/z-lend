// SPDX-License-Identifier: AGPL-1.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Faucet {
	using SafeERC20 for IERC20;

	event Withdrawn(address withdrawer, uint amount);
	uint max = 100 ether;
	mapping(address => mapping(address => uint256)) withdrawals; // sender->token->amount

	constructor() {}

	function withdraw(IERC20 currency, uint amount) public {
		address sender = msg.sender;
		require(withdrawals[sender][address(currency)] + amount <= max, "Max Limit hit");

		withdrawals[sender][address(currency)] += amount;
		currency.safeTransfer(
			// address(this),
			sender,
			amount
		);

		emit Withdrawn(sender, amount);
	}
}
