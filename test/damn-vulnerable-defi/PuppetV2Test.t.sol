// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/09-puppet-v2/PuppetV2Pool.sol";
import "@src/damn-vulnerable-defi/DamnValuableToken.sol";
import "@src/damn-vulnerable-defi/WETH9.sol";
import "@src/damn-vulnerable-defi/09-puppet-v2/Interfaces.sol";
import {sl} from "@solc-log/sl.sol";


/// https://www.damnvulnerabledefi.xyz/challenges/puppet-v2/
contract PuppetV2Test is BaseTest {
  // Uniswap v2 pool will start with 100 tokens and 10 WETH in liquidity
  uint256 public constant UNISWAP_INITIAL_TOKEN_RESERVE = 100e18;
  uint256 public constant UNISWAP_INITIAL_WETH_RESERVE = 10 ether;

  uint256 public constant ATTACKER_INITIAL_TOKEN_BALANCE = 10_000e18;
  uint256 public constant ATTACKER_INITIAL_ETH_BALANCE = 20 ether;

  uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;

  IUniswapV2Pair internal _uniswapV2Pair;
  IUniswapV2Factory internal _uniswapV2Factory;
  IUniswapV2Router02 internal _uniswapV2Router;

  DamnValuableToken internal _token;
  WETH9 internal _weth;

  PuppetV2Pool internal _puppetV2Pool;

  function setUp() public override {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    vm.deal(player, ATTACKER_INITIAL_ETH_BALANCE);

    // Deploy token contracts
    _token = new DamnValuableToken();
    vm.label(address(_token), "DVT");

    _weth = new WETH9();
    vm.label(address(_weth), "WETH");

    // Deploy Uniswap Factory and Router
    _uniswapV2Factory = IUniswapV2Factory(
        deployCode("./src/build-artifacts/uniswap-v2/UniswapV2Factory.json", abi.encode(address(0)))
    );

    _uniswapV2Router = IUniswapV2Router02(
        deployCode(
            "./src/build-artifacts/uniswap-v2/UniswapV2Router02.json",
            abi.encode(address(_uniswapV2Factory), address(_weth))
        )
    );

    // Create Uniswap pair against WETH and add liquidity
    _token.approve(address(_uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
    _uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
      address(_token), 
      UNISWAP_INITIAL_TOKEN_RESERVE, 
      0, 
      0, 
      deployer, 
      block.timestamp
    );

    // Get a reference to the created Uniswap pair
    _uniswapV2Pair = IUniswapV2Pair(_uniswapV2Factory.getPair(address(_token), address(_weth)));

    assertGt(_uniswapV2Pair.balanceOf(deployer), 0); // Deployer has LP tokens

    _puppetV2Pool = new PuppetV2Pool(address(_weth), address(_token), address(_uniswapV2Pair), address(_uniswapV2Factory));

    // Setup initial token balances of pool and attacker account
    _token.transfer(player, ATTACKER_INITIAL_TOKEN_BALANCE);
    _token.transfer(address(_puppetV2Pool), POOL_INITIAL_TOKEN_BALANCE);

    // Ensure correct setup of pool.
    assertEq(_puppetV2Pool.calculateDepositOfWETHRequired(1 ether), 0.3 ether);

    assertEq(_puppetV2Pool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE), 300_000 ether);
  }


  function testPuppetV2() public {
    /** CODE YOUR SOLUTION HERE */

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Attacker has taken all tokens from the pool
    assertEq(_token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    assertEq(_token.balanceOf(address(_puppetV2Pool)), 0);
  }
}
