from brownie import * #NotSoBeefyVault, accounts, DummyERC20, StrategyCommonSolidlyGaugeLP
import time

def main():
    #acct = accounts.load('deployment_account')


    #
    # @dev Sets the value of {token} to the token that the vault will
    # hold as underlying value. It initializes the vault's own 'moo' token.
    # This token is minted when someone does a deposit. It is burned in order
    # to withdraw the corresponding portion of the underlying assets.
    # @param _name the name of the vault token.
    # @param _symbol the symbol of the vault token.
    Vault=NotSoBeefyVault.deploy("shitt", "sas", {'from': accounts[0]})
    time.sleep(1) 

    #
    #   @param address _want -   lp pair to autocomound
    #   @param address _gauge - Reward Gauge
    #   @param address _vault - Connected Vault
    #   @param address _unirouter - Router 
    #   @param address _keeper - _keeper address to use as alternative owner.
    #   @param address _strategist  - address where strategist fees go.
    #
    #
    strat=StrategyCommonSolidlyGaugeLP.deploy(Vault,Vault,Vault,Vault,Vault,Vault,{'from': accounts[0]})
    #print(strat)
    time.sleep(1) 


    Vault.setStrategy(strat,{'from':accounts[0]})
    print('okok fsdo'+ Vault.strategy({'from':accounts[0]}))
    time.sleep(1) 



