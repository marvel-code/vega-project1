// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LotteryStorage} from "./LotteryStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LotteryContract is
    LotteryStorage,
    VRFConsumerBaseV2Plus,
    AutomationCompatibleInterface,
    ReentrancyGuard,
    UUPSUpgradeable
{
    constructor(
        address token_,
        address lendingPool_,
        uint256 subscriptionId_
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        token = token_;
        lendingPool = lendingPool_;
        s_subscriptionId = subscriptionId_;
    }

    // Main logic

    function deposit(uint256 amount_) external nonReentrant {
        require(!lotteryStarted, "Lottery already started");
        require(amount_ > 0, "Amount must be greater than 0");
        require(
            IERC20(token).balanceOf(msg.sender) >= amount_,
            "Insufficient balance"
        );
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount_,
            "Insufficient allowance"
        );
        require(deposits[msg.sender] == 0, "Already deposited");

        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount_),
            "Transfer failed"
        );
        deposits[msg.sender] += amount_;
        totalDeposits += amount_;
        participants.push(msg.sender);
    }

    function startLottery(uint256 duration_) public onlyOwner nonReentrant {
        require(!lotteryStarted, "Lottery already started");
        require(duration_ > 0, "Duration must be greater than 0");
        require(totalDeposits > 0, "No deposits");

        lotteryStarted = true;
        lotteryEnd = block.timestamp + duration_;
        require(
            IERC20(token).approve(lendingPool, totalDeposits),
            "Approve failed"
        );
        try
            IPool(lendingPool).supply(token, totalDeposits, address(this), 0)
        {} catch {
            revert("Supply failed");
        }
    }

    function finishLottery() public onlyOwner nonReentrant {
        require(lotteryStarted, "Lottery not started");
        require(block.timestamp >= lotteryEnd, "Lottery not ended");
        address winner = _selectWinner();
        uint256 withdrawn = IPool(lendingPool).withdraw(
            token,
            type(uint256).max,
            address(this)
        );
        uint256 yield = withdrawn - totalDeposits;
        if (yield > 0) {
            IERC20(token).transfer(winner, yield);
        }
        for (uint256 i = 0; i < participants.length; i++) {
            IERC20(token).transfer(participants[i], deposits[participants[i]]);
            totalDeposits -= deposits[participants[i]];
            deposits[participants[i]] = 0;
        }
        participants = new address[](0);
        lotteryStarted = false;
    }

    // Winner selection

    function _requestRandomNumber() private returns (uint256 requestId) {
        return
            s_vrfCoordinator.requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: s_keyHash,
                    subId: s_subscriptionId,
                    requestConfirmations: requestConfirmations,
                    callbackGasLimit: callbackGasLimit,
                    numWords: numWords,
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                    )
                })
            );
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        randomY = randomWords[0] % totalDeposits;
    }

    function _selectWinner() private view returns (address) {
        require(participants.length > 0, "No participants");
        uint256 y = randomY;
        for (uint256 i = 0; i < participants.length; ++i) {
            if (y < deposits[participants[i]]) {
                return participants[i];
            } else {
                y -= deposits[participants[i]];
            }
        }
        revert("Winner not found");
    }

    // Lottery upkeep

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = block.timestamp >= lotteryEnd;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        finishLottery();
    }

    // UUPS

    function _authorizeUpgrade(address) internal override onlyProxy {}
}
