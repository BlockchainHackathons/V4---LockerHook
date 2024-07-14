// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@pancakeswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./CLBaseHook.sol";
import {Currency, CurrencyLibrary} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {NonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager} from "@pancakeswap/v4-periphery/src/pool-cl/interfaces/INonfungiblePositionManager.sol";
import {CLLockerData} from "./libraries/CLLockerData.sol";
import {Constants} from "./libraries/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract CLLockerHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    NonfungiblePositionManager nfp;

    /// @notice The sender is not the hook
    error SenderMustBeHook();

    /// @notice The position is locked
    error PositionIsLocked();

    /// @notice Interact with a non-initialized pool
    error PoolNotInitialized();

    /// @notice Not the holder of the nft
    error NotOwnerOfSelectedNFT();

    event LiquidityAdded(
        PoolId poolId,
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 unlockDate
    );

    event DecreaseLiquidity(uint256 tokenId, uint128 liquidity, uint256 removedAmount0, uint256 removedAmount1);

    event ExtendLock(uint256 tokenId, uint256 unlockDate);

    mapping(PoolId => mapping(uint256 => CLLockerData.LockInfo)) public lockInfo;

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {
        nfp = NonfungiblePositionManager(payable(0xe05b539447B17630Cb087473F6b50E5c5f73FDeb));
    }

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return
            _hooksRegistrationBitmapFrom(
                Permissions({
                    beforeInitialize: false,
                    afterInitialize: false,
                    beforeAddLiquidity: true,
                    afterAddLiquidity: false,
                    beforeRemoveLiquidity: true,
                    afterRemoveLiquidity: false,
                    beforeSwap: false,
                    afterSwap: false,
                    beforeDonate: false,
                    afterDonate: false,
                    beforeSwapReturnsDelta: false,
                    afterSwapReturnsDelta: false,
                    afterAddLiquidityReturnsDelta: false,
                    afterRemoveLiquidityReturnsDelta: false
                })
            );
    }

    /// @dev Users can only add liquidity through this hook
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override poolManagerOnly returns (bytes4) {
        // if (sender != address(this)) revert SenderMustBeHook();

        return this.beforeAddLiquidity.selector;
    }

    /// @dev Users can only add liquidity through this hook
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override poolManagerOnly returns (bytes4) {
        // if (sender != address(this)) revert SenderMustBeHook();
        return this.beforeRemoveLiquidity.selector;
    }

    function addLiquidity(CLLockerData.AddLiquidityParams calldata params) external {
        PoolKey memory key = PoolKey({
            currency0: params.currency0,
            currency1: params.currency1,
            hooks: this,
            poolManager: poolManager,
            fee: params.fee,
            parameters: params.parameters
        });
        PoolId poolId = key.toId();

        require(
            IERC20(Currency.unwrap(params.currency0)).transferFrom(msg.sender, address(this), params.amount0Desired),
            ""
        );
        require(
            IERC20(Currency.unwrap(params.currency1)).transferFrom(msg.sender, address(this), params.amount1Desired),
            ""
        );

        IERC20(Currency.unwrap(params.currency0)).approve(address(nfp), params.amount0Desired);
        IERC20(Currency.unwrap(params.currency1)).approve(address(nfp), params.amount1Desired);

        (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert PoolNotInitialized();

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            poolKey: key,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            recipient: params.to,
            deadline: params.deadline,
            salt: bytes32(0)
        });

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = nfp.mint(mintParams);

        CLLockerData.LockInfo storage lock = lockInfo[poolId][tokenId];

        lock.unlockDate = params.unlockDate;

        emit LiquidityAdded(poolId, tokenId, liquidity, amount0, amount1, params.unlockDate);
    }

    function decreaseLiquidity(
        CLLockerData.DecreaseLiquidityParams calldata params
    ) external returns (uint256 amount0, uint256 amount1) {
        if (msg.sender == nfp.ownerOf(params.tokenId)) revert NotOwnerOfSelectedNFT();

        PoolKey memory key = PoolKey({
            currency0: params.currency0,
            currency1: params.currency1,
            hooks: this,
            poolManager: poolManager,
            fee: params.fee,
            parameters: params.parameters
        });
        PoolId poolId = key.toId();

        CLLockerData.LockInfo memory lock = lockInfo[poolId][params.tokenId];

        if (block.timestamp >= lock.unlockDate) revert PositionIsLocked();

        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams = INonfungiblePositionManager
            .DecreaseLiquidityParams({
                tokenId: params.tokenId,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: type(uint256).max
            });

        (amount0, amount1) = nfp.decreaseLiquidity(decreaseLiquidityParams);

        emit DecreaseLiquidity(params.tokenId, params.liquidity, amount0, amount1);
    }

    function extendLock(uint256 tokenId, PoolId poolId, uint256 newUnlockDate) external {
        if (msg.sender == nfp.ownerOf(tokenId)) revert NotOwnerOfSelectedNFT();

        require(newUnlockDate > block.timestamp, "New unlock date must be in the future");

        CLLockerData.LockInfo storage lock = lockInfo[poolId][tokenId];

        require(newUnlockDate > lock.unlockDate, "New unlock date must be afterwards the current unlockDate");

        lock.unlockDate = newUnlockDate;

        emit ExtendLock(tokenId, newUnlockDate);
    }
}
