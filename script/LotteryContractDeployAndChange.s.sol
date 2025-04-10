// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryContract} from "../src/LotteryContract.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LotteryContractDeployScript is Script {
    address constant TOKEN_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant POOL_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 constant SUBSCRIPTION_ID = 1;
    address constant PROXY_ADDRESS = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    LotteryContract public lotteryContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        lotteryContract = new LotteryContract(
            TOKEN_ADDRESS,
            POOL_ADDRESS,
            SUBSCRIPTION_ID
        );
        LotteryContract proxy = LotteryContract(PROXY_ADDRESS);
        proxy.upgradeToAndCall(address(lotteryContract), "");

        vm.stopBroadcast();
    }
}
