// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {CLTestUtils} from "./utils/CLTestUtils.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {CLLockerHook} from "../../src/pool-cl/CLLockerHook.sol";
import {CLLockerData} from "../../src/pool-cl/libraries/CLLockerData.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {SortTokens} from "@pancakeswap/v4-core/test/helpers/SortTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CLPoolParametersHelper} from "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol"; // Ensure PoolIdLibrary is imported
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol"; // Import PoolId

contract CLLockerHookTest is Test, CLTestUtils {
    using CLPoolParametersHelper for bytes32;
    using PoolIdLibrary for PoolKey; // Ensure PoolIdLibrary is used for PoolKey

    CLLockerHook hook;
    Currency currency0;
    Currency currency1;
    PoolKey poolKey;

    function setUp() public {
        // Use the existing vault, poolManager, and nfp from CLTestUtils
        (currency0, currency1) = deployContractsWithTokens();

        hook = new CLLockerHook(poolManager);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolManager,
            fee: uint24(3000),
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        // Initialize the pool
        poolManager.initialize(poolKey, 79228162514264337593543950336, "");

        // Approve tokens for the hook contract
        IERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);

        // Approve tokens for the nfp contract
        IERC20(Currency.unwrap(currency0)).approve(address(nfp), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(nfp), type(uint256).max);
    }

    function testPoolNotInitialized() public {
        // Ensure initial token balances are set
        MockERC20(Currency.unwrap(currency0)).mint(address(this), 1000000);
        MockERC20(Currency.unwrap(currency1)).mint(address(this), 1000000);

        // Attempt to add liquidity to an uninitialized pool should revert
        uint256 amount0Desired = 1000;
        uint256 amount1Desired = 1000;
        uint256 amount0Min = 0;
        uint256 amount1Min = 0;
        uint256 deadline = block.timestamp + 1 hours;
        int24 tickLower = -887220;
        int24 tickUpper = 887220;
        uint256 unlockDate = block.timestamp + 30 days;

        // Create a new poolKey with a different fee to simulate an uninitialized pool
        PoolKey memory newPoolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolManager,
            fee: uint24(4000), // Different fee to create a new pool
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        CLLockerData.AddLiquidityParams memory params = CLLockerData.AddLiquidityParams({
            currency0: currency0,
            currency1: currency1,
            fee: uint24(4000),
            parameters: newPoolKey.parameters,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            to: address(this),
            tickLower: tickLower,
            tickUpper: tickUpper,
            deadline: deadline,
            unlockDate: unlockDate
        });

        vm.expectRevert(CLLockerHook.PoolNotInitialized.selector);
        hook.addLiquidity(params);
    }
}
