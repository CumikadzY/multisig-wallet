import web3
import solcx
import os

from dotenv import load_dotenv
from sys import argv

def check_and_throw(condition: bool, response: str):
    if not condition:
        print(response)
        exit()


file_name = argv[1]

check_and_throw(os.path.exists(file_name), f"Nothing to deploy.\nThere is no file: {file_name}")

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)

w3 = web3.Web3(web3.HTTPProvider(os.environ['RPCURL']))

check_and_throw(w3.isConnected(), f"Nothing to deploy.\nThe JSON RPC URL {os.environ['RPCURL']} is not accessible")

master_account = w3.eth.account.from_key(os.environ['PRIVKEY'])
gas_price = int(os.environ['GASPRICE'])
solc_version = os.environ['SOLIDITY'].replace("v", "")
owners = list(set(os.environ['OWNERS'].split(" ")))
threshold = int(os.environ['THRESHOLD'])
wallet_contract = os.environ['WALLETCONTRACT']

if "/" in file_name and "./" not in file_name: #DISPUTE DECESION! IF FAILS - FIX IT!
    pure_file_name = file_name.split("/")[-1]
else:
    pure_file_name = file_name

compiled_contract = solcx.compile_files(file_name, output_values=["abi", "bin"], solc_version=solc_version, solc_binary="/usr/local/bin/solc")

compiled_code = f"{file_name.rstrip('.')}:{wallet_contract}"


check_and_throw(compiled_code in compiled_contract.keys(),
                f"Nothing to deploy.\nThere is no contract `{wallet_contract}` in {file_name}")
ABI = compiled_contract[compiled_code]['abi']
BYTECODE = compiled_contract[compiled_code]['bin']

contract = w3.eth.contract(abi=ABI, bytecode=BYTECODE)
needed_gas = contract.constructor(owners, threshold).estimateGas()
check_and_throw(needed_gas * gas_price <= w3.eth.get_balance(master_account.address),
                f"Nothing to deploy.\nThe balance of the account {master_account.address} is not enough to deploy.")

nonce = w3.eth.getTransactionCount(master_account.address)
tx_hash = contract.constructor(owners, threshold).buildTransaction(
    {'from': master_account.address,
     'chainId': w3.eth.chain_id,
     'gas': needed_gas,
     'gasPrice': gas_price,
     'nonce': nonce,
     "value": 0
     }
)

private_key = master_account.privateKey
signed_txn = w3.eth.account.sign_transaction(tx_hash, private_key=private_key)
contract_id = w3.eth.waitForTransactionReceipt(w3.eth.sendRawTransaction(signed_txn.rawTransaction).hex())["contractAddress"]
print(f"Deployed at {contract_id}")
