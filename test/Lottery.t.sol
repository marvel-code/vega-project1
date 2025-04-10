// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LotteryContract} from "../src/LotteryContract.sol"; // assumes LotteryStorage and dependencies are available
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

contract TestableLottery is LotteryContract {
    constructor(
        address token_,
        address lendingPool_,
        uint256 subscriptionId_
    ) LotteryContract(token_, lendingPool_, subscriptionId_) {}

    function setRandom(uint256 _random) external {
        randomY = _random % participants.length;
    }
}

contract LotteryContractTest is Test {
    address constant WHALE_ADDRESS = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341; // (Mainnet)
    address constant TOKEN_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (Mainnet)
    address constant POOL_ADDRESS = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave Sepolia (Mainnet)
    address constant user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // (anvil test account #0)
    address constant user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // (anvil test account #1)
    TestableLottery lottery;
    IERC20 token;
    IPool pool;

    function setUp() public {
        token = IERC20(TOKEN_ADDRESS);
        pool = IPool(POOL_ADDRESS);
        lottery = new TestableLottery(address(token), address(pool), 1);
        vm.prank(WHALE_ADDRESS);
        token.transfer(address(this), 10000);
    }

    function testDeposit() public {
        uint256 depAmount = 100;
        token.transfer(user, depAmount);
        vm.prank(user);
        token.approve(address(lottery), depAmount);
        vm.prank(user);
        lottery.deposit(depAmount);
        uint256 userDep = lottery.deposits(user);
        assertEq(userDep, depAmount);
        uint256 tot = lottery.totalDeposits();
        assertEq(tot, depAmount);
    }

    function testStartLottery() public {
        uint256 depAmount = 100;
        token.transfer(user, depAmount);
        vm.prank(user);
        token.approve(address(lottery), depAmount);
        vm.prank(user);
        lottery.deposit(depAmount);
        uint256 duration = 3600;
        lottery.startLottery(duration);
        bool started = lottery.lotteryStarted();
        assertTrue(started);
        uint256 endTime = lottery.lotteryEnd();
        assertEq(endTime, block.timestamp + duration);
    }

    function testFinishLottery() public {
        uint256 depAmount = 100;
        token.transfer(user, depAmount);
        vm.prank(user);
        token.approve(address(lottery), depAmount);
        vm.prank(user);
        lottery.deposit(depAmount);
        uint256 duration = 120000000;
        lottery.startLottery(duration);
        vm.warp(block.timestamp + duration + 1);
        lottery.setRandom(50);
        lottery.performUpkeep("");
        bool started = lottery.lotteryStarted();
        assertFalse(started);
        uint256 userBal = token.balanceOf(user);
        assertGe(userBal, 100);
    }

    function testMultipleDeposits() public {
        uint256 depAmountUser1 = 100;
        uint256 depAmountUser2 = 200;
        token.transfer(user, depAmountUser1);
        token.transfer(user2, depAmountUser2);
        vm.prank(user);
        token.approve(address(lottery), depAmountUser1);
        vm.prank(user);
        lottery.deposit(depAmountUser1);
        vm.prank(user2);
        token.approve(address(lottery), depAmountUser2);
        vm.prank(user2);
        lottery.deposit(depAmountUser2);
        uint256 depositUser1 = lottery.deposits(user);
        uint256 depositUser2 = lottery.deposits(user2);
        assertEq(depositUser1, depAmountUser1);
        assertEq(depositUser2, depAmountUser2);
        uint256 total = lottery.totalDeposits();
        assertEq(total, depAmountUser1 + depAmountUser2);
    }

    function testPerformUpkeepTooEarly() public {
        uint256 depAmount = 100;
        token.transfer(user, depAmount);
        vm.prank(user);
        token.approve(address(lottery), depAmount);
        vm.prank(user);
        lottery.deposit(depAmount);
        uint256 duration = 3600;
        lottery.startLottery(duration);
        vm.expectRevert();
        lottery.performUpkeep("");
    }
}
