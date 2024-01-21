// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

contract BaseTest is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    uint256 constant DEPLOYER_INITIAL_FUNDS = 10_000 ether;

    function setUp() public virtual {
      vm.deal(deployer, DEPLOYER_INITIAL_FUNDS);
    }
}
