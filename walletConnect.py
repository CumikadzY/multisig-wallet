from sys import argv
import web3
import solcx
import json
import time
import os
from dotenv import load_dotenv
import eth_abi

class MasterOperation:
    caption_types = ["{}: add {}",
                     "{}: remove {}",
                     "{}: set threshold {}",
                     "{}: {} of ether to {}",
                     "{}: {} of {} to {}"]
    def __init__(self, _oper, _id, _acceptors, _canceled, _owner, _value, _token):
        self.oper = _oper
        self.id = _id
        self.acceptors = _acceptors
        self.canceled = _canceled
        self.owner = _owner
        self.value = _value
        self.token = _token

        _id = make_bytes32(str(hex(_id)))
        caption = self.caption_types[_oper]

        if _oper == 0 :
            self.caption = caption.format(_id,_owner)
        elif _oper == 1:
            self.caption = caption.format(_id,_owner)
        elif _oper == 2:
            self.caption = caption.format(_id,_value)
        elif _oper == 3:
            self.caption = caption.format(_id,_value,_owner)
        else:
            self.caption = caption.format(_id,_value,_token,_owner)

    def __str__(self):
        return f"{self.id} {self.token} {self.owner} {self.value}\n"

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)

w3 = web3.Web3(web3.HTTPProvider(os.environ['RPCURL']))

gas_price = int(os.environ['GASPRICE'])

ABI = '[{"inputs":[{"internalType":"address[]","name":"o","type":"address[]"},{"internalType":"uint256","name":"t","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"id","type":"bytes32"}],"name":"ActionCanceled","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"id","type":"bytes32"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"ActionConfirmed","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"id","type":"bytes32"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"CancelRegistered","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"newowner","type":"address"}],"name":"OwnerAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"}],"name":"OwnerRemoved","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"token","type":"address"},{"indexed":true,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"RequestForTransfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"newowner","type":"address"}],"name":"RequestToAddOwner","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"oldthresh","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"newthresh","type":"uint256"}],"name":"RequestToChangeThreshold","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"}],"name":"RequestToRemoveOwner","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"oldthresh","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"newthresh","type":"uint256"}],"name":"ThresholdChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"token","type":"address"},{"indexed":true,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"TransferExecuted","type":"event"},{"inputs":[{"internalType":"addresspayable","name":"newowner","type":"address"}],"name":"addOwner","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"id","type":"bytes32"}],"name":"cancel","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"thresh","type":"uint256"}],"name":"changeThreshold","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"id","type":"bytes32"}],"name":"confirm","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"oper_id","type":"uint256"}],"name":"getAcceptorsCountById","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"}],"name":"getContractTokenBalance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getOperations","outputs":[{"components":[{"internalType":"uint256","name":"oper_type","type":"uint256"},{"internalType":"uint256","name":"id","type":"uint256"},{"internalType":"address[]","name":"acceptors","type":"address[]"},{"internalType":"address[]","name":"cancelled","type":"address[]"},{"internalType":"addresspayable","name":"owner","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"address","name":"token","type":"address"}],"internalType":"structMultiSigWallet.Operation[]","name":"","type":"tuple[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getOwners","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getThreshold","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getUncompleted","outputs":[{"internalType":"uint256[]","name":"","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getUnconfirmed","outputs":[{"internalType":"uint256[]","name":"","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"id","type":"uint256"},{"internalType":"addresspayable","name":"sender","type":"address"}],"name":"processOperationById","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"addresspayable","name":"owner","type":"address"}],"name":"removeOwner","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"addresspayable","name":"receiver","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"}],"name":"transfer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"addresspayable","name":"receiver","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"}],"name":"transfer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"stateMutability":"payable","type":"receive"}]'

address = web3.Web3.toChecksumAddress(os.environ['WALLETCONTRACTADDRESS'])
contract = w3.eth.contract(address=address, abi=ABI)


def make_bytes32(s: str):
    if "x" not in s:
        s = "0x" + s

    splitted = s.split("x")
    trimmed = splitted[1].lstrip("0")

    return f"{splitted[0]}x{'0' * (64 - len(trimmed))}{trimmed}"


def make_pure_id(s: str):
    return make_bytes32(s)


def getAcceptorsCountById(id_):
    return contract.functions.getAcceptorsCountById(id_).call()


def make_trans(con_fun, *args):  # для вызова функций чтобы не повторять для каждого метода , слать contract.functions.
    nonce = w3.eth.getTransactionCount(master_account.address)
    tx_hash = con_fun(*args).buildTransaction(
        {'from': master_account.address,
         'chainId': w3.eth.chain_id,
         'gas': int(w3.eth.getBlock('latest').gasLimit * 0.95),
         'gasPrice': gas_price,
         'nonce': nonce,
         "value": 0
         }
    )
    private_key = master_account.privateKey
    signed_txn = w3.eth.account.sign_transaction(tx_hash, private_key=private_key)
    h = w3.eth.sendRawTransaction(signed_txn.rawTransaction).hex()
    res = w3.eth.waitForTransactionReceipt(h)
    return h, res

#
def add(addr):
    try:
        web3.Web3.toChecksumAddress(addr)
    except:
        print('It is not the wallet owner. Nothing to do.')
        return

    owners_additions = getoperids(0)

    found_addition = None

    for owners_addition in owners_additions:
        if owners_addition.owner == addr:
            found_addition = owners_addition
            break
    if found_addition:
        if master_account.address in found_addition.acceptors:
            print(f"Confirmation {make_pure_id(str(hex(found_addition.id)))} was already sent. Nothing to do.")
        else:
            print(f"The action {make_pure_id(str(hex(found_addition.id)))} was already initiated. Nothing to do.")
    else:
        thresh = getthresh(False)
        hash, res_dict = make_trans(contract.functions.addOwner, addr)
        id_abi = res_dict['logs'][0]['topics'][1]
        id_ = eth_abi.decode_abi(types=['uint256'], data=id_abi)[0]
        acc_count = getAcceptorsCountById(id_)
        # учти случай когда треш = 1
        if acc_count:
            print(f'Confirmation {make_pure_id(str(id_))}')
            print(f'Sent at {hash}')
            print(f'It is {acc_count} of {thresh} confirmations')
        else:
            print(f'Sent at {hash}')
            print(f'It is {thresh} of {thresh} confirmations -- executed.')



def remove(addr):
    found_removals = None

    owners_removals = getoperids(1)

    for owners_removals in owners_removals:
        if owners_removals.owner == addr:
            found_removals = owners_removals
            break

    if found_removals:
        if master_account.address in found_removals.acceptors:
            print(f"Confirmation {make_pure_id(str(hex(found_removals.id)))} was already sent. Nothing to do.")
        else:
            print(f"The action {make_pure_id(str(hex(found_removals.id)))} was already initiated. Nothing to do.")
    else:
        thresh = getthresh(False)
        hash, res_dict = make_trans(contract.functions.removeOwner, addr)
        id_abi = res_dict['logs'][0]['topics'][1]
        id_ = eth_abi.decode_abi(types=['uint256'], data=id_abi)[0]
        acc_count = getAcceptorsCountById(id_)
        if acc_count:
            print(f'Confirmation {make_pure_id(str(id_))}')
            print(f'Sent at {hash}')
            print(f'It is {acc_count} of {thresh} confirmations')
        else:
            print(f'Sent at {hash}')
            print(f'It is {thresh} of {thresh} confirmations -- executed.')




def setthresh(thresh):
    thresh = int(thresh)
    if master_account.address in getowners(False):
        found_thresh = None

        owners_threshold_changings = getoperids(2)

        for owners_thresh in owners_threshold_changings:
            if owners_thresh.value == thresh:
                found_thresh = owners_thresh
                break

        if found_thresh:
            if master_account.address in found_thresh.acceptors:
                print(f"Confirmation {make_pure_id(str(hex(found_thresh.id)))} was already sent. Nothing to do.")
            else:
                print(f"The action {make_pure_id(str(hex(found_thresh.id)))} was already initiated. Nothing to do.")
        else:
            threshold = getthresh(False)
            hash, res_dict = make_trans(contract.functions.changeThreshold, thresh)
            id_abi = res_dict['logs'][0]['topics'][1]
            id_ = eth_abi.decode_abi(types=['uint256'], data=id_abi)[0]
            acc_count = getAcceptorsCountById(id_)

            if acc_count:
                print(f'Confirmation {make_pure_id(str(hex(id_)))}')
                print(f'Sent at {hash}')
                print(f'It is {acc_count} of {threshold} confirmations')
            else:
                print(f'Sent at {hash}')
                print(f'It is {threshold} of {threshold} confirmations -- executed.')
    else:
        print('It is not the wallet owner. Nothing to do.')

#fixed
def transfer(*args):
    thresh = getthresh(False)
    amount = int(args[-1])
    receiver = args[-2]
    token = None

    is_sending_tokens = len(args) >= 3

    if is_sending_tokens:  # значит, что у нас отправка токенов
        token = args[-3]
        transfers_ethers = getoperids(4)
    else:
        transfers_ethers = getoperids(3)

    found_transfers_eth = None

    for transfer_ether in transfers_ethers:
        if transfer_ether.owner == receiver and transfer_ether.value == amount and (token is None or transfer_ether.token == token):
            found_transfers_eth = transfer_ether
            break

    if found_transfers_eth:
        if master_account.address in found_transfers_eth.acceptors:
            print(f"Confirmation {make_pure_id(str(hex(found_transfers_eth.id)))} was already sent. Nothing to do.")
        else:
            print(f"The action {make_pure_id(str(hex(found_transfers_eth.id)))} was already initiated. Nothing to do.")
    else:
        if is_sending_tokens:
            hash, res_dict = make_trans(contract.functions.transfer, token, receiver, amount)
        else:
            hash, res_dict = make_trans(contract.functions.transfer, receiver, amount)

        id_abi = res_dict['logs'][0]['topics'][1]
        id_ = eth_abi.decode_abi(types=['uint256'], data=id_abi)[0]
        acc_count = getAcceptorsCountById(id_)

        if acc_count:
            print(f'Confirmation {make_pure_id(str(hex(id_)))}')
            print(f'Sent at {hash}')
            print(f'It is {acc_count} of {thresh} confirmations')
        else:
            if len(args) >= 3:  # значит, что у нас отправка токенов
                token = args[-3]
                transfers_ethers = getoperids(4)
            else:
                transfers_ethers = getoperids(3)

            for transfer_ether in transfers_ethers:
                if transfer_ether.id == id_:
                    print('No enough balance on the wallet contract.')
                    break
            else:
                print(f'Sent at {hash}')
                print(f'It is {thresh} of {thresh} confirmations -- executed.')


#
def confirm(id_):
    if int(id_, 16) not in map(lambda x: x.id, getmasteropers()):
        print(f'There is no action with id {make_pure_id(str(id_))}.')
        return
    operations = getmasteropers()
    id__ = int(id_, 16)
    thresh = getthresh(False)
    owners = getowners(False)

    for operation in operations:
        if id__ == operation.id:
            break

    if master_account.address in operation.acceptors:
        print(f"Confirmation {make_pure_id(str(hex(id__)))} was already sent. Nothing to do.")
        return

    if operation.oper == 0 and len(operation.acceptors) == thresh - 1 and operation.owner in owners:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nOwner exists.")
        return

    if operation.oper == 1 and len(operation.acceptors) == thresh - 1 and len(owners) - 1 < thresh:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nNumber of owners cannot be lower confirmations threshold.")
        return

    if operation.oper == 1 and len(operation.acceptors) == thresh - 1 and operation.owner not in owners:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nOwner does not exist.")
        return

    if operation.oper == 2 and len(operation.acceptors) == thresh - 1 and len(owners) < operation.value:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nNumber of owners cannot be lower confirmations threshold.")
        return

    if operation.oper == 2 and len(operation.acceptors) == thresh - 1 and thresh == operation.value:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nConfirmations threshold is the same.")
        return

    if operation.oper == 3 and len(operation.acceptors) == thresh - 1 and w3.eth.get_balance(contract.address) < operation.value:
        print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nNo enough balance on the wallet contract.")
        return

    if operation.oper == 4:
        token_balance = gettokenbalance(operation.token)

        if len(operation.acceptors) == thresh - 1 and (token_balance is None or token_balance == -1):
            print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nIncorrect token contract.")
            return

        if len(operation.acceptors) == thresh - 1 and token_balance < operation.value:
            print(f"It is {thresh} of {thresh} confirmations -- but cannot be executed.\nNo enough tokens balance on the wallet contract.")
            return

    thresh = getthresh(False)
    hash, res_dict = make_trans(contract.functions.confirm, make_bytes32(id_))
    acc_count = getAcceptorsCountById(id__)
    print(f'Sent at {hash}')
    if acc_count:
        print(f'It is {acc_count} of {thresh} confirmations')
    else:
        print(f'It is {thresh} of {thresh} confirmations -- executed.')


#
def cancel(id_):
    master_opers = getmasteropers()
    if int(id_, 16) not in map(lambda x: x.id, master_opers):
        print(f'There is no action with id {make_pure_id(str(id_))}. Nothing to do.')
        return

    for master_oper in master_opers:
        if master_oper.id == int(id_, 16):
            break

    acc_bull = master_account.address in master_oper.acceptors
    can_bull = master_account.address in master_oper.canceled

    if not acc_bull and not can_bull:
        print('There is no confirmation of this owner. Nothing to do.')
    elif not acc_bull and can_bull:
        print("This owner's confirmation already canceled. Nothing to do.")
    else:
        hash, res_dict = make_trans(contract.functions.cancel, make_bytes32(id_))
        print(f'Sent at {hash}')
        acc_count = getAcceptorsCountById(int(id_, 16))
        if acc_count:
            print(f'A confirmation for the action {make_pure_id(str(id_))} canceled. {acc_count} confirmation(s) left.')
        else:
            print(f'All confirmations for the action {make_pure_id(str(id_))} canceled.')



def getowners(bull=True):
    owners = contract.functions.getOwners().call()
    if bull:
        print('The current owners list:')
        print(*owners, sep='\n')
    else:
        return owners


def getthresh(bull=True):
    th = contract.functions.getThreshold().call()
    if bull:
        print(f'Required number of confirmations: {th}')
    else:
        return th


def getmasteropers() -> [MasterOperation]:
    abi = contract.functions.getOperations().call()
    master_opers = list()

    for entry in abi:
        master_opers.append(MasterOperation(*entry))

    return master_opers

def getoperids(op_type) -> [MasterOperation]:
    master_opers = getmasteropers()
    found = list()

    for master_oper in master_opers:
        if master_oper.oper == op_type:
            found.append(master_oper)

    found.sort(key=lambda x: x.id)
    return found

def getunconfirmed():
    ids = list(filter(lambda x: x, contract.functions.getUnconfirmed().call({"from": master_account.address})))

    if len(ids) == 0:
        print("No unconfirmed actions")
        return

    master_opers = getmasteropers()
    found = list()

    for master_oper in master_opers:
        if master_oper.id in ids:
            found.append((master_oper.id, master_oper.caption))

    found.sort(key=lambda x: x[0])

    print(*map(lambda x: x[1], found), sep='\n')


def getuncompleted():
    ids = list(filter(lambda x: x, contract.functions.getUncompleted().call({"from": master_account.address})))

    if len(ids) == 0:
        print("No uncompleted actions")
        return

    master_opers = getmasteropers()
    found = list()

    for master_oper in master_opers:
        if master_oper.id in ids:
            found.append((master_oper.id, master_oper.caption))


    found.sort(key=lambda x: x[0])

    print(*map(lambda x: x[1], found), sep='\n')

def gettokenbalance(token: str):
    try:
        return contract.functions.getContractTokenBalance(token).call()
    except:
        return -1


slaves = argv[1:]
if "get" in slaves[0]:
    command = "".join(slaves)
    if "un" in command: #OMG, really kludgy way
        master_account = w3.eth.account.from_key(os.environ['PRIVKEY'])
    globals()[command]()
    exit()

master_account = w3.eth.account.from_key(os.environ['PRIVKEY'])
if master_account.address in getowners(False):
    command = slaves[0]
    globals()[command](*slaves[1:])
else:
    print("It is not the wallet owner. Nothing to do.")