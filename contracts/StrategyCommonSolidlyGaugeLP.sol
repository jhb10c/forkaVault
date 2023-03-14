// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "OpenZeppelin/openzeppelin-contracts@3.4.0/contracts/math/SafeMath.sol";

import "OpenZeppelin/openzeppelin-contracts@3.4.0/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.4.0/contracts/token/ERC20/SafeERC20.sol";





/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}




/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


contract StratManager is Ownable, Pausable {
    /**
     * @dev Beefy Contracts:
     * {keeper} - Address to manage a few lower risk features of the strat
     * {strategist} - Address of the strategy author/deployer where strategist fee will go.
     * {vault} - Address of the vault that controls the strategy's funds.
     * {unirouter} - Address of exchange to execute swaps.
     */
    address public keeper;
    address public strategist;
    address public unirouter;
    address public vault;
    address public beefyFeeRecipient;

    /**
     * @dev Initializes the base strategy.
     * @param _keeper address to use as alternative owner.
     * @param _strategist address where strategist fees go.
     * @param _unirouter router to use for swaps
     * @param _vault address of parent vault.
     */
    constructor(
        address _keeper,
        address _strategist,
        address _unirouter,
        address _vault
    ) public {
        keeper = _keeper;
        strategist = _strategist;
        unirouter = _unirouter;
        vault = _vault;
    }

    // checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(msg.sender == owner() || msg.sender == keeper, "!manager");
        _;
    }

    /**
     * @dev Updates address of the strat keeper.
     * @param _keeper new keeper address.
     */
    function setKeeper(address _keeper) external onlyManager {
        keeper = _keeper;
    }

    /**
     * @dev Updates address where strategist fee earnings will go.
     * @param _strategist new strategist address.
     */
    function setStrategist(address _strategist) external {
        require(msg.sender == strategist, "!strategist");
        strategist = _strategist;
    }

    /**
     * @dev Updates router that will be used for swaps.
     * @param _unirouter new unirouter address.
     */
    function setUnirouter(address _unirouter) external onlyOwner {
        unirouter = _unirouter;
    }

    /**
     * @dev Updates parent vault.
     * @param _vault new vault address.
     */
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

 

    /**
     * @dev Function to synchronize balances before new user deposit.
     * Can be overridden in the strategy.
     */
    function beforeDeposit() external virtual {}
}



/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */




 abstract contract FeeManager is StratManager {
    uint constant public STRATEGIST_FEE = 112;
    uint constant public MAX_FEE = 1000;
    uint constant public MAX_CALL_FEE = 111;

    uint constant public WITHDRAWAL_FEE_CAP = 50;
    uint constant public WITHDRAWAL_MAX = 10000;

    uint public withdrawalFee = 10;

    uint public callFee = 111;
    uint public beefyFee = MAX_FEE - STRATEGIST_FEE - callFee;

    function setCallFee(uint256 _fee) public onlyManager {
        require(_fee <= MAX_CALL_FEE, "!cap");
        
        callFee = _fee;
        beefyFee = MAX_FEE - STRATEGIST_FEE - callFee;
    }

    function setWithdrawalFee(uint256 _fee) public onlyManager {
        require(_fee <= WITHDRAWAL_FEE_CAP, "!cap");

        withdrawalFee = _fee;
    }
}



interface IERC20Extended {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
}

interface ISolidlyGauge {
    function deposit(uint256 amount, uint256 tokenId) external;
    function withdraw(uint256 amount) external;
    function getReward(address user, address[] memory rewards) external;
    function earned(address token, address user) external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
}

interface ISolidlyPair {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function burn(address to) external returns (uint amount0, uint amount1);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function stable() external view returns (bool);
}

interface IUniswapRouterSolidly {

    // Routes
    struct Routes {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        bool stable, 
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable, 
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn, 
        uint amountOutMin, 
        address tokenFrom, 
        address tokenTo,
        bool stable, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

     function swapExactTokensForTokens(
        uint amountIn, 
        uint amountOutMin, 
        Routes[] memory route, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);
   
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);
}


contract StrategyCommonSolidlyGaugeLP is StratManager {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used

    //rewards token
    address public native;
    //reward token
    address public output;


    //lp pair determined by below to autocomound
    address public want;
    //lp token 
    address public lpToken0;
    //lp token2
    address public lpToken1;

    // Third party contracts
    address public gauge;
    address public intializer;

    bool public stable;
    bool public harvestOnDeposit;
    uint256 public lastHarvest;

    //reward to natice wrapped
    IUniswapRouterSolidly.Routes[] public outputToNativeRoute;
     //reward to l0
    IUniswapRouterSolidly.Routes[] public outputToLp0Route;
    //reward to l1
    IUniswapRouterSolidly.Routes[] public outputToLp1Route;
    address[] public rewards;

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _want,
        address _gauge,
        address _vault,
        address _unirouter,
        address _keeper,
        address _strategist
    ) StratManager(_keeper, _strategist, _unirouter, _vault) public {
        want = _want;
        gauge = _gauge;
        //ISolidlyPair(want).stable();
        stable = true;
        intializer = msg.sender;
    }

    function intializeRoutes(address[][] memory outputToNative, address[][] memory outputToLp0, address[][] memory outputToLp1, bool[][] memory stables) external onlyOwner {
        require(intializer != address(0), "Already Intialized");
        
        _initOutputToNativeRoute(outputToNative, stables[0]);
        _initOutputToLp0Route(outputToLp0, stables[1]);
        _initOutputToLp1Route(outputToLp1, stables[2]);

        output = outputToNativeRoute[0].from;
        native = outputToNativeRoute[outputToNativeRoute.length -1].to;
        lpToken0 = outputToLp0Route[outputToLp0Route.length - 1].to;
        lpToken1 = outputToLp1Route[outputToLp1Route.length - 1].to;

        rewards.push(output);
        _giveAllowances();

        intializer = address(0);
    }

    function _initOutputToNativeRoute(address[][] memory tokens, bool[] memory stables) internal {
        for (uint i; i < tokens.length; ++i) {
            outputToNativeRoute.push(IUniswapRouterSolidly.Routes({
                from: tokens[i][0],
                to: tokens[i][1],
                stable: stables[i]
            }));
        }
    }

    function _initOutputToLp0Route(address[][] memory tokens, bool[] memory stables) internal {
        for (uint i; i < tokens.length; ++i) {
            outputToLp0Route.push(IUniswapRouterSolidly.Routes({
                from: tokens[i][0],
                to: tokens[i][1],
                stable: stables[i]
            }));
        }
    }

     function _initOutputToLp1Route(address[][] memory tokens, bool[] memory stables) internal {
        for (uint i; i < tokens.length; ++i) {
            outputToLp1Route.push(IUniswapRouterSolidly.Routes({
                from: tokens[i][0],
                to: tokens[i][1],
                stable: stables[i]
            }));
        }
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        //get balance
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        //if non zero then deposit into gauge
        if (wantBal > 0) {
            ISolidlyGauge(gauge).deposit(wantBal, 0);
            emit Deposit(balanceOf());
        }
    }


    //
    function withdraw(uint256 _amount) external {
        //onlyvault can withdraw
        require(msg.sender == vault, "!vault");
        //get balance
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        //if amount is large then larger then withdraw from gauge
        if (wantBal < _amount) {
            ISolidlyGauge(gauge).withdraw(_amount.sub(wantBal));
            wantBal = IERC20(want).balanceOf(address(this));
        }
        // if want is larger then amount
        if (wantBal > _amount) {
            wantBal = _amount;
        }

        // Fees
        //if (tx.origin != owner() && !paused()) {
        //    uint256 withdrawalFeeAmount = wantBal.mul(withdrawalFee).div(WITHDRAWAL_MAX);
        //     wantBal = wantBal.sub(withdrawalFeeAmount);
        //}

        // transfer to vault
        IERC20(want).safeTransfer(vault, wantBal);

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external virtual override {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function harvest() external  virtual {
        _harvest();
    }


    // compounds earnings and charges performance fee
    function _harvest() internal whenNotPaused {
        ISolidlyGauge(gauge).getReward(address(this), rewards);
        uint256 outputBal = IERC20(output).balanceOf(address(this));
        if (outputBal > 0) {
            addLiquidity();
            uint256 wantHarvested = balanceOfWant();
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested, balanceOf());
        }
    }


    // Adds liquidity to AMM and gets more LP tokens.
    function addLiquidity() internal {
        uint256 lp0Amt;
        uint256 lp1Amt;
        if (stable) {
            uint256 outputBal = IERC20(output).balanceOf(address(this));
            lp0Amt = outputBal.mul(getRatio()).div(10**18);
            lp1Amt = outputBal.sub(lp0Amt);
        } else { 
            lp0Amt = IERC20(output).balanceOf(address(this)).div(2);
            lp1Amt = lp0Amt;
        }
        //trade rewards for lptoken0
        if (lpToken0 != output) {
            IUniswapRouterSolidly(unirouter).swapExactTokensForTokens(lp0Amt, 0, outputToLp0Route, address(this), now);
        }
        //tradre rewards for lptoken1
        if (lpToken1 != output) {
            IUniswapRouterSolidly(unirouter).swapExactTokensForTokens(lp1Amt, 0, outputToLp1Route, address(this), now);
        }

        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        IUniswapRouterSolidly(unirouter).addLiquidity(lpToken0, lpToken1, stable, lp0Bal, lp1Bal, 1, 1, address(this), now);
    }

//could cause problems?
//works for sure for 19
    function getRatio() public view returns (uint256) {
        (uint256 opLp0, uint256 opLp1, ) = ISolidlyPair(want).getReserves();
        uint256 lp0Amt = opLp0.mul(10**18).div(10**IERC20Extended(lpToken0).decimals());
        uint256 lp1Amt = opLp1.mul(10**18).div(10**IERC20Extended(lpToken1).decimals());   
        uint256 totalSupply = lp0Amt.add(lp1Amt);      
        return lp0Amt.mul(10**18).div(totalSupply);
    }

    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        // balance of this address + balance of pool
        return balanceOfWant().add(balanceOfPool());
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        return ISolidlyGauge(gauge).balanceOf(address(this));
    }

    // returns rewards unharvested
    function rewardsAvailable() public view returns (uint256) {
        return ISolidlyGauge(gauge).earned(output, address(this));
    }



    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
        harvestOnDeposit = _harvestOnDeposit;

    
    }


    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        ISolidlyGauge(gauge).withdraw(balanceOfPool());

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        ISolidlyGauge(gauge).withdraw(balanceOfPool());
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {
        IERC20(want).safeApprove(gauge, uint256(-1));
        IERC20(output).safeApprove(unirouter, uint256(-1));

        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, uint256(-1));

        IERC20(lpToken1).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, uint256(-1));
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(gauge, 0);
        IERC20(output).safeApprove(unirouter, 0);

        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, 0);
    }
}