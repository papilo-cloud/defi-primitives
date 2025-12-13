// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2Pair {
    IERC20 public token0;
    IERC20 public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant MINIMUN_LIQUIDITY = 1000;

    event Mint(
        address indexed sender,
        uint amount0,
        uint amount1
    );

    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    event Sync(uint256 reserve0, uint256 reserve1);

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // ========================================
    // ADD LIQUIDITY
    // ========================================
    function addLiquidity(uint amount0, uint amount1) external returns (uint liquidity) {
        // Transfer token from user
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        uint amount0Added = balance0 - reserve0;
        uint amount1Added = balance1 - reserve1;

        if (totalSupply == 0) {
            // First liquidity provider
            liquidity = sqrt(amount0Added * amount1Added);

            // Burn minimum liquidity (prevents attact)
            totalSupply = MINIMUN_LIQUIDITY;
            balanceOf[address(0)] = MINIMUN_LIQUIDITY;
            liquidity -= MINIMUN_LIQUIDITY;
        } else {
            // Subsequent liquidity provider
            liquidity = min(
                (amount0Added * totalSupply) / reserve0,
                (amount1Added * totalSupply) / reserve1
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        // Mint LP tokens
        totalSupply += liquidity;
        balanceOf[msg.sender] += liquidity;

        // Update reserves
        reserve0 = balance0;
        reserve1 = balance1;

        emit Mint(msg.sender, amount0Added, amount1Added);
        emit Sync(reserve0, reserve1);
    }

    // ========================================
    // REMOVE LIQUIDITY
    // ========================================
    function removeLiquidity(uint liquidity) external returns (uint amount0, uint amount1) {
        require(balanceOf[msg.sender] > liquidity, "Insufficient LP tokens");

        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");

        // Burn LP tokens
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;

        // Transfer tokens
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        // Update reserves
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1, msg.sender);
        emit Sync(reserve0, reserve1);
    }

    // ========================================
    // SWAP
    // ========================================
    function swap(uint amount0Out, uint amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output amount");
        require(amount0Out < reserve0 && amount1Out < reserve1, "Insufficient liquidity");

        // Transfer output tokens
        if (amount0Out > 0) token0.transfer(to, amount0Out);
        if (amount1Out > 0) token1.transfer(to, amount1Out);

        // Get bew balance
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        // calculate input amounts
        uint amount0In = balance0 > reserve0 - amount0Out ? balance0 - (reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > reserve1 - amount1Out ? balance1 - (reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, "Insufficient output amount");

        // Verify k (with 0.3% fee)
        uint balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        require(balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * (1000**2), "K invariant violated");

        // Update reserves
        reserve0 = balance0;
        reserve1 = balance1;

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // Helper functions
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }
}