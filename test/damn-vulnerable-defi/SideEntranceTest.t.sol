// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/04-side-entrance/SideEntranceLenderPool.sol";
import "@src/damn-vulnerable-defi/04-side-entrance/LenderPoolAttacker.sol";

contract SideEntranceTest is BaseTest {
  
  SideEntranceLenderPool pool;

  uint256 constant ETHER_IN_POOL = 1_000 ether;
  uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1 ether;

  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    pool = new SideEntranceLenderPool();
    pool.deposit{value: ETHER_IN_POOL}();
    assertEq(address(pool).balance, ETHER_IN_POOL);

    vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
  }

  function testSideEntrance() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player);
    LenderPoolAttacker attackerContract = new LenderPoolAttacker(address(pool));
    attackerContract.attack(ETHER_IN_POOL);
    

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Player took all ETH from the pool
    assertEq(address(pool).balance, 0);
    assertGt(player.balance, ETHER_IN_POOL);
  }
}
