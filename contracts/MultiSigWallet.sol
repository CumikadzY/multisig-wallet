pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract MultiSigWallet {

    struct Operation {
        uint256 oper_type;
        uint256 id;
        address[] acceptors;
        address[] cancelled;
        address payable owner;
        uint256 value;
        address token;
    }

    modifier isOwner {
        require(isSenderOwner(msg.sender), "Sender is not owner");
        _;
    }

    uint256 constant ADD_OWNER = 0;
    uint256 constant REMOVE_OWNER = 1;
    uint256 constant THRESHOLD_CHANGING = 2;
    uint256 constant TRANSFER_ETH = 3;
    uint256 constant TRANSFER_TOKEN = 4;

    address constant ETHER_ADDRESS = address(0);
    address THIS_ADDRESS = address(this);

    address[] owners;
    uint256 threshold;
    uint256[] owner_addition_op;
    uint256[] owner_removal_op;
    uint256[] threshold_changing_op;
    uint256[] transfer_eth_op;
    uint256[] transfer_token_op;
    Operation[] global_opers;
    uint256 last_id = 1; //in production -1 in each index

    event OwnerAdded(address indexed newowner);
    event ThresholdChanged(uint256 amount, uint256 oldthresh, uint256 newthresh);
    event ActionConfirmed(bytes32 indexed id, address indexed sender);
    event RequestToAddOwner(address indexed newowner);
    event RequestToRemoveOwner(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequestToChangeThreshold(uint256 amount, uint256 oldthresh, uint256 newthresh);
    event RequestForTransfer(address indexed token, address indexed receiver, uint256 value);
    event TransferExecuted(address indexed token, address indexed receiver, uint256 value);
    event CancelRegistered(bytes32 indexed id, address indexed sender);
    event ActionCanceled(bytes32 indexed id);

    constructor(address[] memory o, uint256 t) public {
        require(t != 0, "Threshold cannot be zero.");
        require(t <= o.length, "Threshold cannot be bigger than owners count.");
        require(o.length != 0, "Owners count cannot be zero.");


        bool was = false;

        for (uint256 i = 0; i < o.length; i++) {

            for (uint256 j = i + 1; j < o.length; j++) {
                if (o[i] == o[j]) {
                    was = true;
                    break;
                }
            }
            if (was) {
                break;
            }
        }

        require(!was, "Dublicate in owners.");

        owners = o;
        threshold = t;

        uint256 am = o.length;

        emit ThresholdChanged(am, 0, t);
        for (uint256 i = 0; i < am; i++) {
            emit OwnerAdded(o[i]);
        }

    }

    function getOwners() view public returns (address[] memory) {
        return owners;
    }

    function getUnconfirmed() public view isOwner returns (uint256[] memory) {// 0 means nothing, just skip it. Indexes to show needed to be minused by 1.
        uint256[] memory result = new uint256[](global_opers.length);

        uint256 index = 0;

        for (uint256 i = 0; i < global_opers.length; i++) {
            bool was = false;

                for (uint256 j = 0; j < global_opers[i].acceptors.length; j++) {
                    if (global_opers[i].acceptors[j] == msg.sender) {
                        was = true;
                        break;
                    }
                }

                if (!was) {
                    result[index] = global_opers[i].id;
                    index++;
                }
        }

        return result;
    }

    function getUncompleted() public view isOwner returns (uint256[] memory) {// 0 means nothing, just skip it. Indexes to show needed to be minused by 1.
        uint256[] memory result = new uint256[](global_opers.length);

        uint256 index = 0;

        for (uint256 i = 0; i < global_opers.length; i++) {
            bool was = false;
            
                for (uint256 j = 0; j < global_opers[i].acceptors.length; j++) {
                    if (global_opers[i].acceptors[j] == msg.sender) {
                        was = true;
                        break;
                    }
                }

                if (was) {
                    result[index] = global_opers[i].id;
                    index++;
                }
        }

        return result;
    }

    function getOperations() public view returns (Operation[] memory) {
        return global_opers;
    }

    function getAcceptorsCountById(uint256 oper_id) public view returns (uint256) {
        for (uint256 i = 0; i < global_opers.length; i++) {
            if (global_opers[i].id == oper_id) {
                return global_opers[i].acceptors.length;
            }
        }

        return 0;
    }


    function deleteElementInUint256Array(uint256[] storage _base, uint256 _target) private returns (bool) {
        for (uint256 i = 0; i < _base.length; i++) {
            if (_base[i] == _target) {
                _base[i] = _base[_base.length - 1];
                _base.pop();

                return true;
            }
        }

        return false;
    }

    function deleteElementInAddressArray(address[] storage _base, address _target) private returns (bool) {
        for (uint256 i = 0; i < _base.length; i++) {
            if (_base[i] == _target) {
                _base[i] = _base[_base.length - 1];
                _base.pop();

                return true;
            }
        }

        return false;
    }

    function isSenderOwner(address sender) view private returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (sender == owners[i]) {
                return true;
            }
        }
        return false;
    }


    function deleteOperation(uint256 oper_id) private {
        for (uint256 i = 0; i < global_opers.length; i++) {
            if (global_opers[i].id == oper_id) {
                global_opers[i] = global_opers[global_opers.length - 1];
                global_opers.pop();
                break;
            }
        }
    }

    function getContractTokenBalance(address _token) external view returns (uint256) {
        IERC20 tkn = IERC20(_token);
        return tkn.balanceOf(address(this));
    }

    function processOperation(uint256 oper_type, address payable sender, address payable owner, uint256 value, address token) private {
        uint256[] memory ids_to_find;

        if (oper_type == ADD_OWNER) {
            ids_to_find = owner_addition_op;
        } else if (oper_type == REMOVE_OWNER) {
            ids_to_find = owner_removal_op;
        } else if (oper_type == THRESHOLD_CHANGING) {
            ids_to_find = threshold_changing_op;
        } else if (oper_type == TRANSFER_ETH) {
            ids_to_find = transfer_eth_op;
        } else {
            ids_to_find = transfer_token_op;
        }

        uint256 acceptors_count = 0;
        bool is_operation_exist = false;
        uint256 oper_id;
        uint256 global_id;

        for (uint256 i = 0; i < ids_to_find.length; i++) {
            bool condition = false;

            if (oper_type == ADD_OWNER) {
                condition = global_opers[i].owner == owner;
            } else if (oper_type == REMOVE_OWNER) {
                condition = global_opers[i].owner == owner;
            } else if (oper_type == THRESHOLD_CHANGING) {
                condition = global_opers[i].value == value;
            } else if (oper_type == TRANSFER_ETH) {
                condition = global_opers[i].value == value && global_opers[i].owner == owner;
            } else {
                condition = global_opers[i].value == value && global_opers[i].owner == owner && global_opers[i].token == token;
            }
            if (condition) {
                oper_id = i;
                global_id = global_opers[i].id;

                bool is_checlk_norm = true;
                for (uint256 j = 0; j < global_opers[i].acceptors.length; j++) {
                    is_checlk_norm = is_checlk_norm && (global_opers[i].acceptors[j] != sender);
                }
                is_operation_exist = true;

                require(is_checlk_norm, "Chelik is not norm");

                acceptors_count = global_opers[i].acceptors.length;

                if (acceptors_count == threshold - 1) {
                    if (oper_type == ADD_OWNER) {
                        require(!isSenderOwner(owner), "User is already owner");
                    } else if (oper_type == REMOVE_OWNER) {
                        require(isSenderOwner(owner) && threshold <= owners.length - 1, "User is not one of the owners or threshold is gonna be too high");
                    } else if (oper_type == THRESHOLD_CHANGING) {
                        require(value != threshold && value <= owners.length, "Incorrect threshold");
                    } else if (oper_type == TRANSFER_ETH) {
                        require(address(this).balance >= global_opers[i].value, "Low balance.");
                    } else if (oper_type == TRANSFER_TOKEN) {
                        IERC20 tkn = IERC20(global_opers[i].token);
                        require(tkn.balanceOf(address(this)) >= global_opers[i].value, "Low balance.");
                    }
                }

                acceptors_count++;
                global_opers[i].acceptors.push(sender);
                //addOperationAcceptor(global_id, msg.sender);

                emit ActionConfirmed(bytes32(global_opers[oper_id].id), sender);


                break;
            }

        }

        if (!is_operation_exist) {
            last_id += 1;
            global_id = last_id;
            address[] memory a;
            address[] memory c;
            Operation memory newOperation = Operation(oper_type, last_id, a, c, address(this), 0, address(0));

            global_opers.push(newOperation);
            oper_id = global_opers.length - 1;

            global_opers[oper_id].acceptors.push(sender);

            if (oper_type == ADD_OWNER) {
                global_opers[oper_id].owner = owner;
                owner_addition_op.push(last_id);
            } else if (oper_type == REMOVE_OWNER) {
                global_opers[oper_id].owner = owner;
                owner_removal_op.push(last_id);
            } else if (oper_type == THRESHOLD_CHANGING) {
                global_opers[oper_id].value = value;
                threshold_changing_op.push(last_id);
            } else if (oper_type == TRANSFER_ETH) {
                global_opers[oper_id].value = value;
                global_opers[oper_id].owner = owner;
                transfer_eth_op.push(last_id);
            } else {
                global_opers[oper_id].value = value;
                global_opers[oper_id].owner = owner;
                global_opers[oper_id].token = token;
                transfer_token_op.push(last_id);
            }


            acceptors_count = 1;
            //createOperation(msg.sender, global_id);
            emit ActionConfirmed(bytes32(last_id), sender);


            if (oper_type == ADD_OWNER) {
                emit RequestToAddOwner(owner);
            } else if (oper_type == REMOVE_OWNER) {
                emit RequestToRemoveOwner(owner);
            } else if (oper_type == THRESHOLD_CHANGING) {
                emit RequestToChangeThreshold(owners.length, threshold, value);
            } else if (oper_type == TRANSFER_ETH) {
                emit RequestForTransfer(ETHER_ADDRESS, owner, value);
            } else {
                emit RequestForTransfer(token, owner, value);
            }

        }

        if (acceptors_count >= threshold) {
            bool additionalCondition = false;
            if (oper_type == ADD_OWNER) {
                additionalCondition = !isSenderOwner(owner);
            } else if (oper_type == REMOVE_OWNER) {
                additionalCondition = (owners.length - 1) >= threshold && isSenderOwner(owner);
            } else if (oper_type == THRESHOLD_CHANGING) {
                additionalCondition = value > 0 && value <= owners.length;
            } else if (oper_type == TRANSFER_ETH) {
                additionalCondition = THIS_ADDRESS.balance >= value;
            } else {
                IERC20 tkn = IERC20(address(token));
                additionalCondition = tkn.balanceOf(THIS_ADDRESS) >= value;
            }

            if (additionalCondition) {
                if (oper_type == ADD_OWNER) {
                    owners.push(owner);
                    emit OwnerAdded(owner);
                    deleteElementInUint256Array(owner_addition_op, global_id);
                } else if (oper_type == REMOVE_OWNER) {
                    deleteElementInAddressArray(owners, owner);
                    emit OwnerRemoved(owner);
                    deleteElementInUint256Array(owner_removal_op, global_id);
                } else if (oper_type == THRESHOLD_CHANGING) {
                    emit ThresholdChanged(owners.length, threshold, value);
                    threshold = value;
                    deleteElementInUint256Array(threshold_changing_op, global_id);
                } else if (oper_type == TRANSFER_ETH) {
                    owner.transfer(value);
                    emit TransferExecuted(address(0), owner, value);
                    deleteElementInUint256Array(transfer_eth_op, global_id);
                } else {
                    IERC20 tkn = IERC20(token);
                    tkn.transfer(owner, value);
                    emit TransferExecuted(token, owner, value);
                    deleteElementInUint256Array(transfer_token_op, global_id);
                }

                deleteOperation(global_id);
            }
        }
    }

    function processOperationById(uint256 id, address payable sender) external {
        for (uint256 i = 0; i < global_opers.length; i++) {
            if (global_opers[i].id == id) {
                processOperation(global_opers[i].oper_type, sender, global_opers[i].owner, global_opers[i].value, global_opers[i].token);
                break;
            }
        }
    }


    function addOwner(address payable newowner) external isOwner {
        processOperation(ADD_OWNER, msg.sender, newowner, 0, ETHER_ADDRESS);
    }


    function removeOwner(address payable owner) external isOwner {
        processOperation(REMOVE_OWNER, msg.sender, owner, 0, ETHER_ADDRESS);
    }

    function changeThreshold(uint256 thresh) external isOwner {
        processOperation(THRESHOLD_CHANGING, msg.sender, address(this), thresh, ETHER_ADDRESS);
    }

    function getThreshold() view public returns (uint256) {
        return threshold;
    }

    function transfer(address payable receiver, uint256 value) external isOwner {
        processOperation(TRANSFER_ETH, msg.sender, receiver, value, ETHER_ADDRESS);
    }

    function transfer(address token, address payable receiver, uint256 value) external isOwner {
        processOperation(TRANSFER_TOKEN, msg.sender, receiver, value, token);
    }


    function cancel(bytes32 id) external isOwner {
        bool was = false;

        for (uint256 i = 0; i < global_opers.length; i++) {
            if (global_opers[i].id == uint256(id)) {
                bool wwas = false;

                for (uint256 j = 0; j < global_opers[i].acceptors.length; j++) {
                    if (global_opers[i].acceptors[j] == msg.sender) {
                        global_opers[i].acceptors[j] = global_opers[i].acceptors[global_opers[i].acceptors.length - 1];
                        global_opers[i].acceptors.pop();

                        global_opers[i].cancelled.push(msg.sender);

                        emit CancelRegistered(id, msg.sender);
                        wwas = true;
                        break;
                    }
                }

                require(wwas, "Not found in acceptors");

                if (global_opers[i].acceptors.length == 0) {
                    uint256 global_id = global_opers[i].id;
                    uint256 oper_type = global_opers[i].oper_type;

                    global_opers[i] = global_opers[global_opers.length - 1];
                    global_opers.pop();

                    if (oper_type == ADD_OWNER) {
                        deleteElementInUint256Array(owner_addition_op, global_id);
                    } else if (oper_type == REMOVE_OWNER) {
                        deleteElementInUint256Array(owner_removal_op, global_id);
                    } else if (oper_type == THRESHOLD_CHANGING) {
                        deleteElementInUint256Array(threshold_changing_op, global_id);
                    } else if (oper_type == TRANSFER_ETH) {
                        deleteElementInUint256Array(transfer_eth_op, global_id);
                    } else {
                        deleteElementInUint256Array(transfer_token_op, global_id);
                    }

                    emit ActionCanceled(id);

                }
                was = true;
                break;
            }
        }

        require(was, "Action not found.");

    }

    function confirm(bytes32 id) external isOwner {
        this.processOperationById(uint256(id), msg.sender);
    }

    receive() payable external {}
}
