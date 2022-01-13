from brownie import network, accounts, config, Contract, MockV3Aggregator, VRFCoordinatorMock, LinkToken, interface

FORKED_LOCAL_ENVIRONMENTS = ["mainnet-fork", "mainnet-fork-dev"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]

def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        # load previously created brownie account
        # these accounts can be found using the command `brownie accounts list`
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])

contract_to_mock = {
    # you can always find these mock contracts in https://github.com/smartcontractkit/chainlink-mix/tree/master/contracts/test
    "eth_usd_price_feed": MockV3Aggregator,
    "vrf_coordinator": VRFCoordinatorMock,
    "link_token": LinkToken,
}

def get_contract(contract_name):
    """This function will grab the contract addresses from the brownie config
    if defined, otherwise, it will deploy a mock version of that contract, and
    return that mock contract.

        Args:
            contract_name (string)

        Returns:
            brownie.network.contract.ProjectContract: The most recently deployed
            version of this contract.
    """
    contract_type = contract_to_mock[contract_name]
    print(contract_type)
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        # MockV3Aggregator.length
        if len(contract_type) <= 0:
            deploy_mocks()
        # MockV3Aggregator[-1]
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        contract = Contract.from_abi(contract_type._name, contract_address, contract_type.abi)
    
    return contract



DECIMALS = 8
INITIAL_VALUE = 200000000000

def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    print("Started deploying mocks")
    account = get_account()
    MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
    link_token = LinkToken.deploy({"from": account})
    VRFCoordinatorMock.deploy(link_token.address, {"from": account})
    print("Deploying mocks succeeded")

def fund_with_link(contract_address, account=None, link_token=None, amount=100000000000000000): # 0.1 LINK
    account = account if account else get_account()
    link_token = link_token if link_token else get_contract("link_token")

    # the line below is another way to interact with contract that has already been deployed
    tx = link_token.transfer(contract_address, amount, {"from": account})
    # if we have the interface we don't even need to compile down to the api ourselves, because brownie is smart
    # enough to know that it can compile down to the api itself and we can just work directly with that interface
    # link_token_contract = interface.LinkTokenInterface(link_token.address)
    # tx = link_token_contract.transfer(contract_address, amount, {"from": account})
    
    tx.wait(1)
    print("Funded contract")
    return tx