// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@solmate/src/tokens/ERC20.sol";
import "@src/damn-vulnerable-defi/naive-receiver/NaiveReceiverLenderPool.sol";
import "@src/damn-vulnerable-defi/naive-receiver/FlashLoanReceiver.sol";
import "@src/damn-vulnerable-defi/naive-receiver/LoanReceiverAttacker.sol";

contract NaiveReceiverTest is BaseTest {
  address user = makeAddr("user");
  NaiveReceiverLenderPool pool;
  FlashLoanReceiver receiver;

    // Pool has 1000 ETH in balance
  uint256 constant ETHER_IN_POOL = 1_000 ether;
      // Receiver has 10 ETH in balance
  uint256 constant ETHER_IN_RECEIVER = 10 ether;


  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    pool = new NaiveReceiverLenderPool();
    (bool success, ) = address(pool).call{value: ETHER_IN_POOL}("");
    assertTrue(success);
    address ETH = pool.ETH();
    assertEq(address(pool).balance, ETHER_IN_POOL);
    assertEq(pool.maxFlashLoan(ETH), ETHER_IN_POOL);
    assertEq(pool.flashFee(ETH, 0), 1 ether);

    receiver = new FlashLoanReceiver(address(pool));
    (success, ) = address(receiver).call{value: ETHER_IN_RECEIVER}("");
    assertTrue(success);

    vm.expectRevert();
    receiver.onFlashLoan(deployer, ETH, ETHER_IN_RECEIVER, 1 ether, "0x");

    assertEq(address(receiver).balance, ETHER_IN_RECEIVER);
  }

  function testDoSFlashLoans() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player);
    LoanReceiverAttacker attackContract = new LoanReceiverAttacker(
      receiver,
      IPool(address(pool)),
      pool.ETH()
    );
    attackContract.attackReceiver();

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // All ETH has been drained from the receiver
    vm.stopPrank();
    vm.startPrank(deployer);
    assertEq(address(receiver).balance, 0);
    assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
  }
}