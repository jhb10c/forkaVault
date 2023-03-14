import pytest

from brownie import NotSoBeefyVault, accounts, DummyERC20



@pytest.fixture
def token():
    #ok=DummyERC20.deploy('Test','Token',{'from':accounts[0]})
    #assert ok.name({'from':accounts[0]}) != '100'
    return DummyERC20.deploy('Test','Token',{'from':accounts[0]})

@pytest.fixture
def vault():
    tokes=DummyERC20.deploy('Test','Token',{'from':accounts[0]})
    return NotSoBeefyVault.deploy(tokes, "shitt", "sas", {'from': accounts[0]})


def test_name(vault):
    assert vault.name({"from": accounts[0]}) == "shitt"

def test_notName(vault):
    assert vault.name({"from": accounts[0]}) != "poo"

