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
import {CLLockerData} from "../src/pool-cl/libraries/CLLockerData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICLSwapRouter} from "@pancakeswap/v4-periphery/src/pool-cl/interfaces/ICLSwapRouter.sol";

// ICLSwapRouterBase Interface
interface ICLSwapRouterBase {
    struct V4CLExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        address recipient;
        uint128 amountIn;
        uint128 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
        bytes hookData;
    }

    function V4CLExactInputSingle(V4CLExactInputSingleParams calldata params) external returns (uint256 amountOut);
}

contract DeployFullRangeNouns is Script {
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
            MockERC20(0x6bE16988159AE1C6Dda1941931Fd40DF620fF89C),
            MockERC20(0x7e4A3fAeDE9D042D0a7e8491E48aa6F33c31dc4F)
        );
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolm,
            fee: uint24(3000),
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(10)
        });
        console.log("FullRangeNouns deployed at:");
        vm.startBroadcast();
        //poolm.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);
        //swapTokens(key);
        //addLiquidity(hook, key);
        decreaseLiquidity(hook, key);
        vm.stopBroadcast();
    }

    function addLiquidity(CLLockerHook hook, PoolKey memory key) internal {
        uint256 amount0Desired = 1000; // Example amount
        uint256 amount1Desired = 1000; // Example amount
        uint256 amount0Min = 0;
        uint256 amount1Min = 0;
        uint256 deadline = block.timestamp + 1 hours;
        int24 tickLower = -887220;
        int24 tickUpper = 887220;
        uint256 unlockDate = 0;//block.timestamp ;//+ 30 days;

        // Assuming currency0 and currency1 are addresses, if not use appropriate method
        address currency0Address = 0x7e4A3fAeDE9D042D0a7e8491E48aa6F33c31dc4F;
        address currency1Address = 0x6bE16988159AE1C6Dda1941931Fd40DF620fF89C;
        address poolManagerAddress = 0x40a081A39E9638fa6e2463B92A4eff4Bdf877179;
        //approve the hook
        IERC20(currency0Address).approve(address(hook), amount0Desired);
        IERC20(currency1Address).approve(address(hook), amount1Desired);

    
              
        CLLockerData.AddLiquidityParams memory params = CLLockerData.AddLiquidityParams({
            currency0: currency0,
            currency1: currency1,
            fee: uint24(3000),
            parameters: key.parameters,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            to: msg.sender,
            tickLower: tickLower,
            tickUpper: tickUpper,
            deadline: deadline,
            unlockDate: unlockDate
        });

        hook.addLiquidity(params);
    }

    function decreaseLiquidity(CLLockerHook hook, PoolKey memory key) internal {
        uint256 amount0Min = 0;
        uint256 amount1Min = 0;
        uint128 liquidity = 100; // Example liquidity amount
        uint256 tokenId = 9; // Example tokenId

        CLLockerData.DecreaseLiquidityParams memory params = CLLockerData.DecreaseLiquidityParams({
            currency0: currency0,
            currency1: currency1,
            fee: uint24(3000),
            parameters: key.parameters,
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min: amount0Min,
            amount1Min: amount1Min
        });

        (uint256 amount0, uint256 amount1) = hook.decreaseLiquidity(params);
        console.log("Liquidity decreased:", amount0, amount1);
    }

    function swapTokens(PoolKey memory key) internal {
        address currency0Address = 0x6bE16988159AE1C6Dda1941931Fd40DF620fF89C;
        address currency1Address = 0x7e4A3fAeDE9D042D0a7e8491E48aa6F33c31dc4F;
        address swapRouterAddress = 0xA1eA7A788E69161E717a2bF61b7fCb7547745F31; // Replace with actual SwapRouter address
        uint256 amountIn = 100; // Example amount to swap
        uint256 amountOutMin = 0; // Minimum amount of tokens to receive
        address tokenIn = currency0Address; // Token to swap from
        address tokenOut = currency1Address; // Token to swap to
        uint256 deadline = block.timestamp + 1 hours;

        IERC20(tokenIn).approve(swapRouterAddress, amountIn);
        IERC20(tokenOut).approve(swapRouterAddress, amountIn);

        ICLSwapRouterBase.V4CLExactInputSingleParams memory params = ICLSwapRouterBase.V4CLExactInputSingleParams({
            poolKey: key,
            zeroForOne: true, // Assuming tokenIn is token0 and tokenOut is token1; adjust if opposite
            recipient: msg.sender,
            amountIn: uint128(amountIn-100),
            amountOutMinimum: uint128(amountOutMin),
            sqrtPriceLimitX96: 0,
            hookData: ""
        });

        ICLSwapRouterBase swapRouter = ICLSwapRouterBase(swapRouterAddress);

        uint256 amountOut = swapRouter.V4CLExactInputSingle(params);
       
    }
}
