// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/interfaces/INonfungiblePositionManager.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {CLLockerHook} from "./pool-cl/CLLockerHook.sol";
import {Currency, CurrencyLibrary} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {Deployers} from "@pancakeswap/v4-core/test/pool-cl/helpers/Deployers.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";

contract Launcher is Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using CLPoolParametersHelper for bytes32;

    NonfungiblePositionManager nfp;
    ICLPoolManager poolm;
    CLLockerHook clockhook;

    event Initialize(PoolId poolId, Currency currency0, Currency currency1, uint24 fee, CLLockerHook clockhook);

    constructor() {
        nfp = NonfungiblePositionManager(payable(0xe05b539447B17630Cb087473F6b50E5c5f73FDeb));
        poolm = ICLPoolManager(address(0x40a081A39E9638fa6e2463B92A4eff4Bdf877179));
        clockhook = CLLockerHook(0x2BdD231a07076ba609F4B7eC50226296d5A73B16);
    }

    function initializePool(Currency currency0, Currency currency1, uint24 fee) external {
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: clockhook,
            poolManager: poolm,
            fee: fee,
            parameters: bytes32(uint256(clockhook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        PoolId poolId = key.toId();

        poolm.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);

        emit Initialize(poolId, currency0, currency1, fee, clockhook);
    }
}
