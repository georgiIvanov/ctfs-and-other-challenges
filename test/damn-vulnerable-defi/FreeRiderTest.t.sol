// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/10-free-rider/FreeRiderNFTMarketplace.sol";
import "@src/damn-vulnerable-defi/10-free-rider/FreeRiderRecovery.sol";
import "@src/damn-vulnerable-defi/10-free-rider/FlashBuyer.sol";
import "@src/damn-vulnerable-defi/DamnValuableToken.sol";
import "@src/damn-vulnerable-defi/WETH9.sol";
import "@src/damn-vulnerable-defi/09-puppet-v2/Interfaces.sol";
import {sl} from "@solc-log/sl.sol";


/// https://www.damnvulnerabledefi.xyz/challenges/free-rider/
/// The task is to send all minted NFTs from the marketplace to the recovery contract and unlock the reward.
contract FreeRiderTest is BaseTest {
  // The NFT marketplace will have 6 tokens, at 15 ETH each
  uint256 internal constant NFT_PRICE = 15 ether;
  uint8 internal constant AMOUNT_OF_NFTS = 6;
  uint256 internal constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

  // The buyer will offer 45 ETH as payout for the job
  uint256 internal constant BUYER_PAYOUT = 45 ether;

  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;

  // Initial reserves for the Uniswap v2 pool
  uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000 ether;
  uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;

  FreeRiderNFTMarketplace internal freeRiderNFTMarketplace;
  FreeRiderRecovery internal freeRiderRecovery;
  DamnValuableToken internal token;
  DamnValuableNFT internal damnValuableNFT;
  IUniswapV2Pair internal uniswapV2Pair;
  IUniswapV2Factory internal uniswapV2Factory;
  IUniswapV2Router02 internal uniswapV2Router;
  WETH9 internal weth;
  address payable internal buyer;

  function setUp() public override {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    buyer = payable(makeAddr("buyer"));
    vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
    vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE);
    vm.deal(buyer, BUYER_PAYOUT);
    vm.startPrank(deployer);

    // Deploy token contracts
    token = new DamnValuableToken();
    vm.label(address(token), "DVT");

    weth = new WETH9();
    vm.label(address(weth), "WETH");

    // Deploy Uniswap Factory and Router
    uniswapV2Factory = IUniswapV2Factory(
        deployCode("./src/build-artifacts/uniswap-v2/UniswapV2Factory.json", abi.encode(address(0)))
    );

    uniswapV2Router = IUniswapV2Router02(
        deployCode(
            "./src/build-artifacts/uniswap-v2/UniswapV2Router02.json",
            abi.encode(address(uniswapV2Factory), address(weth))
        )
    );

    // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
    // The function takes care of deploying the pair automatically
    token.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
    uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE} (
      address(token), 
      UNISWAP_INITIAL_TOKEN_RESERVE, 
      0, 
      0, 
      deployer, 
      block.timestamp
    );

    // Get a reference to the created Uniswap pair
    uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.getPair(address(token), address(weth)));
    assertEq(uniswapV2Pair.token0(), address(weth));
    assertEq(uniswapV2Pair.token1(), address(token));
    assertGt(uniswapV2Pair.balanceOf(deployer), 0);

    freeRiderNFTMarketplace = new FreeRiderNFTMarketplace{
      value: MARKETPLACE_INITIAL_ETH_BALANCE
    }(AMOUNT_OF_NFTS);

    damnValuableNFT = DamnValuableNFT(freeRiderNFTMarketplace.token());

    for (uint8 id = 0; id < AMOUNT_OF_NFTS; id++) {
      assertEq(damnValuableNFT.ownerOf(id), deployer);
    }

    damnValuableNFT.setApprovalForAll(address(freeRiderNFTMarketplace), true);

    uint256[] memory NFTsForSell = new uint256[](6);
    uint256[] memory NFTsPrices = new uint256[](6);
    for (uint8 i; i < AMOUNT_OF_NFTS; ++i) {
        NFTsForSell[i] = i;
        NFTsPrices[i] = NFT_PRICE;
    }

    freeRiderNFTMarketplace.offerMany(NFTsForSell, NFTsPrices);

    assertEq(freeRiderNFTMarketplace.offersCount(), AMOUNT_OF_NFTS);
    vm.stopPrank();

    vm.startPrank(buyer);

    freeRiderRecovery = new FreeRiderRecovery{value: BUYER_PAYOUT}(player, address(damnValuableNFT));

    vm.stopPrank();
  }


  function testFreeRider() public {
    /** CODE YOUR SOLUTION HERE */
    vm.startPrank(player, player);
    sl.log("NFT Marketplace ETH balance: ", address(freeRiderNFTMarketplace).balance);

    FlashBuyer fb = new FlashBuyer(
      address(uniswapV2Pair),
      payable(address(weth)),
      payable(address(freeRiderNFTMarketplace)),
      payable(address(freeRiderRecovery)),
      player
    );
    // Buy all the NFT, exploiting a bug in the marketplace
    fb.flashBuy{value: player.balance}();

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Attacker must have earned all ETH from the payout
    assertGt(player.balance, BUYER_PAYOUT, "player must get payout");
    assertEq(address(freeRiderRecovery).balance, 0, "freeRiderRecovery must have 0 balance");

    // The buyer extracts all NFTs from its associated contract
    vm.startPrank(buyer);
    for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
        damnValuableNFT.transferFrom(address(freeRiderRecovery), buyer, tokenId);
        assertEq(damnValuableNFT.ownerOf(tokenId), buyer);
    }
    vm.stopPrank();

    // Exchange must have lost NFTs and ETH
    assertEq(freeRiderNFTMarketplace.offersCount(), 0);
    assertLt(address(freeRiderNFTMarketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);
  }
}
