// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LotteryStorage {
    // Token
    address public token;
    // Aave
    address public lendingPool;
    // Chainlink VRF
    uint256 s_subscriptionId;
    address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 s_keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256 randomY;
    // Lottery
    bool public lotteryStarted;
    uint256 public lotteryEnd;
    address[] public participants;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
}
