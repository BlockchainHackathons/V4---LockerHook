pragma solidity ^0.8.24;
import {Currency, CurrencyLibrary} from "@pancakeswap/v4-core/src/types/Currency.sol";

library CLLockerData {
    struct LockInfo {
        uint256 unlockDate;
    }

    struct AddLiquidityParams {
        Currency currency0;
        Currency currency1;
        uint24 fee;
        bytes32 parameters;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address to;
        uint256 deadline;
        uint256 unlockDate;
    }
    struct DecreaseLiquidityParams {
        Currency currency0;
        Currency currency1;
        uint24 fee;
        bytes32 parameters;
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
    }
}
