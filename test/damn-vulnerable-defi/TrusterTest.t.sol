// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@solmate/src/tokens/ERC20.sol";
import "@src/damn-vulnerable-defi/03-truster/TrusterLenderPool.sol";
import "@src/damn-vulnerable-defi/03-truster/TrustAttacker.sol";
import "@src/damn-vulnerable-defi/DamnValuableToken.sol";

contract TrusterTest is BaseTest {
  
  DamnValuableToken token;
  TrusterLenderPool pool;

  uint256 constant TOKENS_IN_POOL = 1_000_000 ether;


  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    token = new DamnValuableToken();
    pool = new TrusterLenderPool(token);
    assertEq(address(pool.token()), address(token));

    token.transfer(address(pool), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(player)), 0);
  }

  function testTruster() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player);
    TrustAttacker attackContract = new TrustAttacker(address(pool));
    attackContract.attack(TOKENS_IN_POOL);

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    assertEq(token.balanceOf(address(player)), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), 0);
  }
}