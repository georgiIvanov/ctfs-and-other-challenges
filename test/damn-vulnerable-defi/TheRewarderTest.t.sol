// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/the-rewarder/FlashLoanerPool.sol";
import "@src/damn-vulnerable-defi/the-rewarder/TheRewarderPool.sol";
import "src/damn-vulnerable-defi/DamnValuableToken.sol";

contract TheRewarderTest is BaseTest {
  
  address[] users;
  address alice = makeAddr("alice");
  address bob = makeAddr("bob");
  address charlie = makeAddr("charlie");
  address david = makeAddr("david");
  uint256 constant TOKENS_IN_LENDER_POOL = 1_000_000 ether;
  DamnValuableToken liquidityToken;
  FlashLoanerPool flashLoanPool;
  TheRewarderPool rewarderPool;
  RewardToken rewardToken;
  AccountingToken accountingToken;

  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);

    users = new address[](4);
    users[0] = alice;
    users[1] = bob;
    users[2] = charlie;
    users[3] = david;

    liquidityToken = new DamnValuableToken();
    flashLoanPool = new FlashLoanerPool(address(liquidityToken));

    // Set initial token balance of the pool offering flash loans
    liquidityToken.transfer(address(flashLoanPool), TOKENS_IN_LENDER_POOL);

    rewarderPool = new TheRewarderPool(address(liquidityToken));
    rewardToken = rewarderPool.rewardToken();
    vm.label(address(rewardToken), "RewardToken");
    accountingToken = rewarderPool.accountingToken();
    vm.label(address(accountingToken), "AccountingToken");

    // Check roles in accounting token
    assertEq(accountingToken.owner(), address(rewarderPool));
    uint256 minterRole = accountingToken.MINTER_ROLE();
    uint256 snapshotRole = accountingToken.SNAPSHOT_ROLE();
    uint256 burnerRole = accountingToken.BURNER_ROLE();
    assertTrue(accountingToken.hasAllRoles(address(rewarderPool), minterRole | snapshotRole | burnerRole));
    vm.stopPrank();

    // Alice, Bob, Charlie and David deposit tokens
    uint256 depositAmount = 100 * 10e18;
    for (uint8 i; i < users.length; ++i) {
      vm.startPrank(deployer);
      liquidityToken.transfer(users[i], depositAmount);
      vm.startPrank(users[i]);
      liquidityToken.approve(address(rewarderPool), depositAmount);
      rewarderPool.deposit(depositAmount);

      assertEq(accountingToken.balanceOf(users[i]), depositAmount);
    }

    assertEq(accountingToken.totalSupply(), depositAmount * users.length);
    assertEq(rewardToken.totalSupply(), 0);
    
    // Advance time 5 days so that depositors can get rewards
    vm.warp(block.timestamp + 5 days);
    
    // Each depositor gets reward tokens
    uint256 rewardsInRound = rewarderPool.REWARDS();
    for (uint8 i; i < users.length; ++i) {
      vm.startPrank(users[i]);
      rewarderPool.distributeRewards();
      assertEq(rewardToken.balanceOf(users[i]), rewardsInRound / users.length);
    }
    assertEq(rewardToken.totalSupply(), rewardsInRound);

    // Player starts with zero DVT tokens in balance
    assertEq(liquidityToken.balanceOf(player), 0);
    
    // Two rounds must have occurred so far
    assertEq(rewarderPool.roundNumber(), 2);
  }

  function testRewarderPool() public {
    /** CODE YOUR SOLUTION HERE */

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Only one round must have taken place
    assertEq(rewarderPool.roundNumber(), 3);

    // Users should get neglegible rewards this round
    for (uint8 i; i < users.length; ++i) {
      vm.startPrank(users[i]);
      uint256 userRewards = rewardToken.balanceOf(users[i]);
      uint256 delta = userRewards - (rewarderPool.REWARDS() / users.length);
      assertLt(delta, 10e16);
    }
    
    // Rewards must have been issued to the player account
    assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
    uint256 playerRewards = rewardToken.balanceOf(player);
    assertGt(playerRewards, 0);

    // The amount of rewards earned should be close to total available amount
    uint256 delta = rewarderPool.REWARDS() - playerRewards;
    assertLt(delta, 10e17);

    // Balance of DVT tokens in player and lending pool hasn't changed
    assertEq(liquidityToken.balanceOf(player), 0);
    assertEq(liquidityToken.balanceOf(address(flashLoanPool)), TOKENS_IN_LENDER_POOL);
  }
}