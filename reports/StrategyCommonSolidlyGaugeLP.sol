// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "reports/IUniswapRouterSolidly.sol";
import "reports/ISolidlyPair.sol";
import "reports/ISolidlyGauge.sol";
import "reports/IERC20Extended.sol";
import "reports/StratManager.sol";
import "reports/FeeManager.sol";

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

        stable = ISolidlyPair(want).stable();
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

        // transfer to vault
        IERC20(want).safeTransfer(vault, wantBal);

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external virtual override {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest(tx.origin);
        }
    }

    function harvest() external gasThrottle virtual {
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

    function setShouldGasThrottle(bool _shouldGasThrottle) external onlyManager {
        shouldGasThrottle = _shouldGasThrottle;
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