// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title DamnValuableTokenSnapshot
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract DamnValuableTokenSnapshot is ERC20Votes {

    constructor(uint256 initialSupply) ERC20("DamnValuableToken", "DVT") EIP712("DamnValuableToken", "1") {
        _mint(msg.sender, initialSupply);
    }

    function getBalanceAtLastSnapshot(address account) external view returns (uint256) {
        return _getVotingUnits(account);
    }

    function getTotalSupplyAtLastSnapshot() external view returns (uint256) {
        return totalSupply();
    }
}