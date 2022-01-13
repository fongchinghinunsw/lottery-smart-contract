from brownie import Lottery, accounts, config, network
from web3 import Web3

def test_get_entrance_fee():
    account = accounts[0]
    lottery = Lottery.deploy(
        config["networks"][network.show_active()]["eth_usd_price_feed"],
        {"from": account})
    # assume the price of 1 ETH = 3000 USD, since the entrance fee is 50 USD
    # 50 / 3000 = 0.16777...
    assert lottery.getEntranceFee() > Web3.toWei(0.016, "ether")
    assert lottery.getEntranceFee() < Web3.toWei(0.018, "ether")