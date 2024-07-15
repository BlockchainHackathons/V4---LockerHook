// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CLLockerHook} from "../src/pool-cl/CLLockerHook.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {console} from "forge-std/console.sol";

import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
contract Deploy is Script {
    function run() external {
        address poolManagerAddress = 0x40a081A39E9638fa6e2463B92A4eff4Bdf877179;
        address nfp = 0xe05b539447B17630Cb087473F6b50E5c5f73FDeb;

        vm.startBroadcast();
        CLLockerHook LockerHook = new CLLockerHook(ICLPoolManager(poolManagerAddress),NonfungiblePositionManager(payable(nfp)));
        vm.stopBroadcast();

        console.log("Deployed at:", address(LockerHook));
    }
}