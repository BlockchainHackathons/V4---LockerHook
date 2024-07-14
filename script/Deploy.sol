// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CLLockerHook} from "../src/pool-cl/CLLockerHook.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {console} from "forge-std/console.sol";
contract Deploy is Script {
    function run() external {
        address poolManagerAddress = 0x40a081A39E9638fa6e2463B92A4eff4Bdf877179;

        vm.startBroadcast();
        CLLockerHook LockerHook = new CLLockerHook(ICLPoolManager(poolManagerAddress));
        vm.stopBroadcast();

        console.log("Deployed at:", address(LockerHook));
    }
}