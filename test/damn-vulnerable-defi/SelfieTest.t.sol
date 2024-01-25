// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/selfie/SelfiePool.sol";
import "@src/damn-vulnerable-defi/selfie/SimpleGovernance.sol";
import "src/damn-vulnerable-defi/DamnValuableTokenSnapshot.sol";

contract SelfieTest is BaseTest {
  
  DamnValuableTokenSnapshot token;
  SimpleGovernance governance;
  SelfiePool pool;

  uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000 * 10e18;
  uint256 constant TOKENS_IN_POOL = 1_500_000 * 10e18;

  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);

    // Deploy Damn Valuable Token Snapshot
    token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);

    // Deploy governance contract
    governance = new SimpleGovernance(address(token));
    assertEq(governance.getActionCounter(), 1);

    // Deploy the pool
    pool = new SelfiePool(address(token), address(governance));
    assertEq(address(pool.token()), address(token));
    assertEq(address(pool.governance()), address(governance));

    // Fund the pool
    token.transfer(address(pool), TOKENS_IN_POOL);
    token.snapshot();
    assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
    assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
    assertEq(pool.flashFee(address(token), 0), 0);
  }

  function testSelfie() public {
    /** CODE YOUR SOLUTION HERE */

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Player has taken all tokens from the pool
    assertEq(token.balanceOf(address(player)), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), 0);
  }
}
