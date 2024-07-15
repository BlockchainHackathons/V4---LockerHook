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
import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract CLLockerHook is CLBaseHook, ERC721Enumerable {
    using PoolIdLibrary for PoolKey;

    NonfungiblePositionManager public nfp;

    /// @notice The sender is not the hook
    error SenderMustBeHook();

    /// @notice The position is locked
    error PositionIsLocked();

    /// @notice Interact with a non-initialized pool
    error PoolNotInitialized();

    /// @notice Not the holder of the nft
    error NotOwnerOfSelectedNFT();

    /// @notice Insufficient liquidity in the position
    error InsufficientLiquidity(uint128 available, uint128 required);

    /// @notice Failed to transfer token
    error TransferFailed();

    /// @notice New unlock date must be in the future
    error UnlockDateInFuture();

    /// @notice New unlock date must be after the current unlock date
    error UnlockDateAfterCurrent();

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

    constructor(ICLPoolManager _poolManager, NonfungiblePositionManager _nfp) 
        CLBaseHook(_poolManager) 
        ERC721("Liquidity Position", "LQP")
    {
        nfp = _nfp;
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
        return this.beforeAddLiquidity.selector;
    }

    /// @dev Users can only add liquidity through this hook
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override poolManagerOnly returns (bytes4) {
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

        if (!IERC20(Currency.unwrap(params.currency0)).transferFrom(msg.sender, address(this), params.amount0Desired)) {
            revert TransferFailed();
        }
        if (!IERC20(Currency.unwrap(params.currency1)).transferFrom(msg.sender, address(this), params.amount1Desired)) {
            revert TransferFailed();
        }

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
            recipient: address(this),//params.to,
            deadline: params.deadline,
            salt: bytes32(0)
        });
        
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = nfp.mint(mintParams);

        CLLockerData.LockInfo storage lock = lockInfo[poolId][tokenId];

        lock.unlockDate = params.unlockDate;

        _mint(msg.sender, tokenId);

        emit LiquidityAdded(poolId, tokenId, liquidity, amount0, amount1, params.unlockDate);
    }

    function decreaseLiquidity(
        CLLockerData.DecreaseLiquidityParams calldata params
    ) external returns (uint256 amount0, uint256 amount1) {
        if (ownerOf(params.tokenId) != msg.sender) {
            revert NotOwnerOfSelectedNFT();
        }

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

        if (block.timestamp <= lock.unlockDate) {
            revert PositionIsLocked();
        }

        // Retrieve the position details
        ( , , , , , , , uint128 liquidity, , , , , ) = nfp.positions(params.tokenId);

        // Check if the position has enough liquidity to be decreased
        if (liquidity < params.liquidity) {
            revert InsufficientLiquidity(liquidity, params.liquidity);
        }

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
        if (ownerOf(tokenId) != msg.sender) {
            revert NotOwnerOfSelectedNFT();
        }

        if (newUnlockDate <= block.timestamp) {
            revert UnlockDateInFuture();
        }

        CLLockerData.LockInfo storage lock = lockInfo[poolId][tokenId];

        if (newUnlockDate <= lock.unlockDate) {
            revert UnlockDateAfterCurrent();
        }

        lock.unlockDate = newUnlockDate;

        emit ExtendLock(tokenId, newUnlockDate);
    }
}
