// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/interfaces/INonfungiblePositionManager.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {CLLockerHook} from "../src/pool-cl/CLLockerHook.sol";
import {Currency, CurrencyLibrary} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {Deployers} from "@pancakeswap/v4-core/test/pool-cl/helpers/Deployers.sol";
import {Script} from "forge-std/Script.sol";
import {SortTokens} from "@pancakeswap/v4-core/test/helpers/SortTokens.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {console} from "forge-std/console.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";

contract InteractLiq is Script {
    using CLPoolParametersHelper for bytes32;
    
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    bytes constant ZERO_BYTES = new bytes(0);
    Currency currency0;
    Currency currency1;

    function run() external {
        address poolManagerAddress = 0x40a081A39E9638fa6e2463B92A4eff4Bdf877179;
        CLLockerHook hook = CLLockerHook(0x74980ccF8f43C772dD89B824561f8803eC4A4960);
        ICLPoolManager poolm = ICLPoolManager(poolManagerAddress);
        (currency0, currency1) = SortTokens.sort(
            MockERC20(0x7e4A3fAeDE9D042D0a7e8491E48aa6F33c31dc4F),
            MockERC20(0x6bE16988159AE1C6Dda1941931Fd40DF620fF89C)
        );
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolm,
            fee: uint24(3000),
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });
        vm.startBroadcast();
        poolm.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);
        vm.stopBroadcast();

    }
}
