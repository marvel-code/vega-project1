// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryContract} from "../src/LotteryContract.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LotteryContractDeployScript is Script {
    address constant TOKEN_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant POOL_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 constant SUBSCRIPTION_ID = 1;

    LotteryContract public lotteryContract;
    ERC1967Proxy public proxy;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        lotteryContract = new LotteryContract(
            TOKEN_ADDRESS,
            POOL_ADDRESS,
            SUBSCRIPTION_ID
        );
        proxy = new ERC1967Proxy(address(lotteryContract), "");

        vm.stopBroadcast();
    }
}
