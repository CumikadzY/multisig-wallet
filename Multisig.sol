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

   contract Multisig {

       struct OwnerAddition{
           uint256 id;
           address[] acceptors;
           address newowner;
       }

       struct OwnerRemoving{
           uint256 id;
           address[]  acceptors;
           address owner;
       }

       struct ThresholdChanging{
           uint256 id;
           address[]  acceptors;
           uint256 value;
       }

       struct TransferEth{
           uint256 id;
           address[]  acceptors;
           address payable receiver;
           uint256 value;
       }

       struct TransferToken{
           uint256 id;
           address[]  acceptors;
           address receiver;
           uint256 value;
           address token;
       }

       struct Operation {
           address[] acceptors;
           uint256 id;
       }

       modifier isOwner {
           if (isSenderOwner(msg.sender)) {
               _;
           }
       }

       address[] owners;
       uint256 threshold;
       OwnerAddition[] owner_addition_op;
       OwnerRemoving[] owner_removing_op;
       ThresholdChanging[] threshold_changing_op;
       TransferEth[] transfer_eth_op;
       TransferToken[] transfer_token_op;
       mapping (uint256 => bytes32) opers_types;
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

       constructor( address[] memory o, uint256 t ) public {
           owners = o;
           threshold = t;

           uint256 am = o.length;

           emit ThresholdChanged(am, 0, t);
           for(uint256 i = 0; i < am; i++){
               emit OwnerAdded(o[i]);
           }

       }

       function isSenderOwner(address sender) view private returns (bool) {
           for (uint256 i = 0; i < owners.length; i++){
               if (sender == owners[i]) {
                   return true;
               }
           }
           return false;
       }

       function addOperationAcceptor(uint256 oper_id, address acceptor) private {
           for (uint256 i = 0; i < global_opers.length; i++) {
               if (global_opers[i].id == oper_id) {
                   global_opers[i].acceptors.push(acceptor);
                   break;
               }
           }
       }

       function removeOperationAcceptor(uint256 oper_id, address acceptor) private {
            for (uint256 i = 0; i < global_opers.length; i++) {
               if (global_opers[i].id == oper_id) {
                   for (uint256 j = 0; j < global_opers[i].acceptors.length; j++) {
                   if (global_opers[i].acceptors[j] == acceptor) {
                       delete global_opers[i].acceptors[j];
                       break;
                       }
                   }
                   break;
               }
           }
       }

        function createOperation(address owner, uint256 oper_id) private {
           address[] memory acceptors;
           global_opers.push(Operation(acceptors, oper_id));
           global_opers[global_opers.length - 1].acceptors.push(owner);
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

       function addOwner(address newowner) external isOwner {
               uint256 acceptors_count = 0;
               bool is_operation_exist = false;
               uint256 oper_id;
               uint256 global_id;

               for (uint256 i = 0; i < owner_addition_op.length; i++){
                       if (owner_addition_op[i].newowner == newowner){
                           oper_id = i;
                           global_id = owner_addition_op[i].id;

                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < owner_addition_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (owner_addition_op[i].acceptors[j] != msg.sender);
                           }
                           is_operation_exist = true;
                           if (is_checlk_norm){
                               owner_addition_op[i].acceptors.push(msg.sender);
                               addOperationAcceptor(global_id, msg.sender);
                               acceptors_count = owner_addition_op[i].acceptors.length;
                               emit ActionConfirmed(bytes32(owner_addition_op[oper_id].id), msg.sender);
                           }

                           break;
                       }

               }

               if (!is_operation_exist){
                   last_id += 1;
                   global_id = last_id;
                   address[] memory q;
                   OwnerAddition memory newOwnerAddition = OwnerAddition({
                       id: last_id,
                       acceptors: q,
                       newowner: newowner
                       });

                   owner_addition_op.push(newOwnerAddition);
                   opers_types[last_id] = "ADD_OWNER";
                   uint256 nl = owner_addition_op.length;
                   oper_id = nl - 1;
                   owner_addition_op[oper_id].acceptors.push(msg.sender);
                   acceptors_count = 1;
                   createOperation(msg.sender, global_id);
                   emit ActionConfirmed(bytes32(last_id), msg.sender);
                   emit RequestToAddOwner(newowner);

               }


               if (acceptors_count >= threshold && !isSenderOwner(newowner)){
                   owners.push(newowner);



                   deleteOperation(global_id);
                   emit OwnerAdded(newowner);

                   owner_addition_op[oper_id] = owner_addition_op[owner_addition_op.length - 1];
                   owner_addition_op.pop();
               }
       }

       function getOwners() view public returns (address[] memory) {
           return owners;
       }


       function removeOwner(address owner) external isOwner {
               uint256 acceptors_count = 0;
               bool is_operation_exist = false;
               uint256 oper_id;
               uint256 global_id;

               for (uint256 i = 0; i < owner_removing_op.length; i++){
                       if (owner_removing_op[i].owner == owner){
                           oper_id = i;
                           global_id = owner_removing_op[i].id;
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < owner_removing_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (owner_removing_op[i].acceptors[j] != msg.sender);
                           }

                           is_operation_exist = true;

                           if (is_checlk_norm){
                               owner_removing_op[i].acceptors.push(msg.sender);
                               acceptors_count = owner_removing_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(owner_removing_op[oper_id].id), msg.sender);
                           }

                             break;
                   }
               }

               if (!is_operation_exist){
                   last_id += 1;
                   global_id = last_id;
                   address[] memory q;
                   OwnerRemoving memory newOwnerRemoving = OwnerRemoving({
                       id: last_id,
                       acceptors: q,
                       owner: owner
                       });

                   owner_removing_op.push(newOwnerRemoving);
                   opers_types[last_id] = "REMOVE_OWNER";
                   uint256 nl = owner_removing_op.length;
                   oper_id = nl - 1;
                   owner_removing_op[oper_id].acceptors.push(msg.sender);
                   acceptors_count = 1;
                   createOperation(msg.sender, global_id);
                   emit ActionConfirmed(bytes32(last_id), msg.sender);
                   emit RequestToRemoveOwner(owner);

               }


               if (acceptors_count >= threshold && (owners.length - 1) >= threshold){
                   deleteOperation(global_id);

                   for (uint256 j = 0; j < owners.length; j++){
                       if (owners[j] == owner){
                           uint256 index = j;
                           for (uint i = index; i < owners.length-1; i++){
                               owners[i] = owners[i+1];
                           }
                           delete owners[owners.length-1];
                           owners.pop();
                           break;
                       }
                   }
                   emit OwnerRemoved(owner);

                   owner_removing_op[oper_id] = owner_removing_op[owner_removing_op.length - 1];
                   owner_removing_op.pop();
               }
       }

       function changeThreshold(uint256 thresh) external isOwner {
               uint256 acceptors_count = 0;
               bool is_operation_exist = false;
               uint256 oper_id;
               uint256 global_id;

               for (uint256 i = 0; i < threshold_changing_op.length; i++){
                   if (threshold_changing_op[i].value == thresh){
                           oper_id = i;
                           global_id = threshold_changing_op[i].id;

                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < threshold_changing_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (threshold_changing_op[i].acceptors[j] != msg.sender);
                           }

                           is_operation_exist = true;

                           if (is_checlk_norm){
                               threshold_changing_op[i].acceptors.push(msg.sender);
                               acceptors_count = threshold_changing_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(threshold_changing_op[oper_id].id), msg.sender);
                           }

                           break;
                       }
               }

               if (!is_operation_exist){
                   address[] memory q;
                   last_id += 1;
                   global_id = last_id;
                   ThresholdChanging memory newTreshChanging = ThresholdChanging({
                       id: last_id,
                       acceptors: q,
                       value: thresh
                   });

                   threshold_changing_op.push(newTreshChanging);
                   uint256 nl = threshold_changing_op.length;
                   oper_id = nl - 1;
                   opers_types[last_id] = "CHANGE_THRESHOLD";
                   threshold_changing_op[oper_id].acceptors.push(msg.sender);
                   acceptors_count = 1;
                   createOperation(msg.sender, global_id);
                   emit ActionConfirmed(bytes32(last_id), msg.sender);
                   emit RequestToChangeThreshold(owners.length, threshold, thresh);
               }

               if (acceptors_count >= threshold && thresh <= owners.length){
                   deleteOperation(global_id);

                   emit ThresholdChanged(owners.length, threshold, thresh);
                   threshold = thresh;

                   threshold_changing_op[oper_id] = threshold_changing_op[threshold_changing_op.length - 1];
                   threshold_changing_op.pop();
               }
       }

       function getThreshold() view public returns (uint256) {
           return threshold;
       }

       function transfer(address payable receiver, uint256 value) external isOwner {
                   if (address(this).balance >= value){
               uint256 acceptors_count = 0;
               bool is_operation_exist = false;
               uint256 oper_id;
               uint256 global_id;

               for (uint256 i = 0; i < transfer_eth_op.length; i++){
                       if (transfer_eth_op[i].receiver == receiver && transfer_eth_op[i].value == value){
                           oper_id = i;
                           global_id = transfer_eth_op[i].id;
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < transfer_eth_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (transfer_eth_op[i].acceptors[j] != msg.sender);
                           }

                           is_operation_exist = true;
                           if (is_checlk_norm){
                               transfer_eth_op[i].acceptors.push(msg.sender);
                               acceptors_count = transfer_eth_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(transfer_eth_op[oper_id].id), msg.sender);
                           }

                           break;
                       }
               }

               if (!is_operation_exist){
                   address[] memory q;
                   TransferEth memory newOwnerAddition = TransferEth({
                       id: ++last_id,
                       acceptors: q,
                       receiver: receiver,
                       value: value
                       });
                   global_id = last_id;
                   transfer_eth_op.push(newOwnerAddition);
                   opers_types[last_id] = "TRANSFER";
                   uint256 nl = transfer_eth_op.length;
                   oper_id = nl - 1;
                   transfer_eth_op[oper_id].acceptors.push(msg.sender);
                   acceptors_count = 1;
                   createOperation(msg.sender, global_id);
                   emit ActionConfirmed(bytes32(transfer_eth_op[oper_id].id), msg.sender);
                   emit RequestForTransfer(address(0), receiver, value);

               }

               if (acceptors_count >= threshold && address(this).balance >= value){
                   deleteOperation(global_id);

                   receiver.transfer(value);
                   emit TransferExecuted(address(0), receiver, value);
                   transfer_eth_op[oper_id] = transfer_eth_op[transfer_eth_op.length - 1];
                   transfer_eth_op.pop();
               }
           }
       }

       function transfer(address token, address receiver, uint256 value) external isOwner {
           IERC20 tkn = IERC20(token);
               if (tkn.balanceOf(address(this)) >= value){
               uint256 acceptors_count = 0;
               bool is_operation_exist = false;
               uint256 oper_id;
               uint256 global_id;

               for (uint256 i = 0; i < transfer_token_op.length; i++){
                       if (transfer_token_op[i].receiver == receiver && transfer_token_op[i].value == value && transfer_token_op[i].token == token){
                           oper_id = i;
                           global_id = transfer_token_op[i].id;
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < transfer_token_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (transfer_token_op[i].acceptors[j] != msg.sender);
                           }

                           is_operation_exist = true;
                           if (is_checlk_norm){
                               transfer_token_op[i].acceptors.push(msg.sender);
                               acceptors_count = transfer_token_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(transfer_token_op[oper_id].id), msg.sender);
                           }

                           break;
                       }
               }

               if (!is_operation_exist){
                   address[] memory q;
                   last_id += 1;
                   global_id = last_id;
                   TransferToken memory newOwnerAddition = TransferToken({
                       id: last_id,
                       acceptors: q,
                       receiver: receiver,
                       value: value,
                       token: token
                       });

                   transfer_token_op.push(newOwnerAddition);
                   opers_types[last_id] = "TRANSFER_TOKEN";
                   uint256 nl = transfer_token_op.length;
                   oper_id = nl - 1;
                   transfer_token_op[oper_id].acceptors.push(msg.sender);
                   acceptors_count = 1;
                   createOperation(msg.sender, global_id);
                   emit ActionConfirmed(bytes32(transfer_token_op[oper_id].id), msg.sender);
                   emit RequestForTransfer(token, receiver, value);

               }

               if (acceptors_count >= threshold && tkn.balanceOf(address(this)) >= value){
                   deleteOperation(global_id);


                   tkn.transfer(receiver, value);
                   emit TransferExecuted(token, receiver, value);
                   transfer_token_op[oper_id] = transfer_token_op[transfer_token_op.length - 1];
                   transfer_token_op.pop();
               }
           }
       }

       function cancel(bytes32 id) external isOwner {
               bytes32 o_type = opers_types[uint256(id)];
                   if (o_type == bytes32("ADD_OWNER")){
                       for (uint256 i = 0; i < owner_addition_op.length; i++){
                           if (owner_addition_op[i].id == uint256(id)){
                               for (uint256 j = 0; j < owner_addition_op[i].acceptors.length; j++){
                                   if (owner_addition_op[i].acceptors[j] == msg.sender){
                                       uint256 index = j;
                                       for (uint z = index; z < owner_addition_op[i].acceptors.length-1; z++){
                                           owner_addition_op[i].acceptors[z] = owner_addition_op[i].acceptors[z+1];
                                       }
                                       delete owner_addition_op[i].acceptors[owner_addition_op[i].acceptors.length-1];
                                       removeOperationAcceptor(uint256(id), msg.sender);
                                       owner_addition_op[i].acceptors.pop();
                                       emit CancelRegistered(id, msg.sender);
                                       break;
                                   }
                               }

                               if (owner_addition_op[i].acceptors.length == 0){
                                   owner_addition_op[i] = owner_addition_op[owner_addition_op.length - 1];
                                   owner_addition_op.pop();
                                   deleteOperation(uint256(id));
                                   emit ActionCanceled(id);
                                   break;
                               }
                           }
                       }
                   }

                   if (o_type == bytes32("REMOVE_OWNER")){
                       for (uint256 i = 0; i < owner_removing_op.length; i++){
                           if (owner_removing_op[i].id == uint256(id)){
                               for (uint256 j = 0; j < owner_removing_op[i].acceptors.length; j++){
                                   if (owner_removing_op[i].acceptors[j] == msg.sender){
                                       uint256 index = j;
                                       for (uint z = index; z < owner_removing_op[i].acceptors.length-1; z++){
                                           owner_removing_op[i].acceptors[z] = owner_removing_op[i].acceptors[z+1];
                                       }
                                       delete owner_removing_op[i].acceptors[owner_removing_op[i].acceptors.length-1];
                                       removeOperationAcceptor(uint256(id), msg.sender);
                                       owner_removing_op[i].acceptors.pop();
                                       emit CancelRegistered(id, msg.sender);
                                       break;
                                   }
                               }

                               if (owner_removing_op[i].acceptors.length == 0){
                                   owner_removing_op[i] = owner_removing_op[owner_removing_op.length - 1];
                                   owner_removing_op.pop();


                                    deleteOperation(uint256(id));
                                   emit ActionCanceled(id);
                                   break;
                               }
                           }
                       }
                   }

                   if (o_type == bytes32("CHANGE_THRESHOLD")){
                       for (uint256 i = 0; i < threshold_changing_op.length; i++){
                           if (threshold_changing_op[i].id == uint256(id)){
                               for (uint256 j = 0; j < threshold_changing_op[i].acceptors.length; j++){
                                   if (threshold_changing_op[i].acceptors[j] == msg.sender){
                                       uint256 index = j;
                                       for (uint z = index; z < threshold_changing_op[i].acceptors.length-1; z++){
                                           threshold_changing_op[i].acceptors[z] = owner_addition_op[i].acceptors[z+1];
                                       }
                                       delete threshold_changing_op[i].acceptors[threshold_changing_op[i].acceptors.length-1];
                                       removeOperationAcceptor(uint256(id), msg.sender);
                                       threshold_changing_op[i].acceptors.pop();
                                       emit CancelRegistered(id, msg.sender);
                                       break;
                                   }
                               }

                               if (threshold_changing_op[i].acceptors.length == 0){
                                   threshold_changing_op[i] = threshold_changing_op[threshold_changing_op.length - 1];
                                   threshold_changing_op.pop();
                                    deleteOperation(uint256(id));
                                   emit ActionCanceled(id);
                                   break;
                               }
                           }
                       }
                   }

                   if (o_type == bytes32("TRANSFER")){
                       for (uint256 i = 0; i < transfer_eth_op.length; i++){
                           if (transfer_eth_op[i].id == uint256(id)){
                               for (uint256 j = 0; j < transfer_eth_op[i].acceptors.length; j++){
                                   if (transfer_eth_op[i].acceptors[j] == msg.sender){
                                       uint256 index = j;
                                       for (uint z = index; z < transfer_eth_op[i].acceptors.length-1; z++){
                                           transfer_eth_op[i].acceptors[z] = transfer_eth_op[i].acceptors[z+1];
                                       }
                                       delete transfer_eth_op[i].acceptors[transfer_eth_op[i].acceptors.length-1];
                                       removeOperationAcceptor(uint256(id), msg.sender);
                                       transfer_eth_op[i].acceptors.pop();
                                       emit CancelRegistered(id, msg.sender);
                                       break;
                                   }
                               }

                               if (transfer_eth_op[i].acceptors.length == 0){
                                   transfer_eth_op[i] = transfer_eth_op[transfer_eth_op.length - 1];
                                   transfer_eth_op.pop();
                                     deleteOperation(uint256(id));
                                   emit ActionCanceled(id);
                                   break;
                               }
                           }
                       }
                   }

                   if (o_type == bytes32("TRANSFER_TOKEN")){
                       for (uint256 i = 0; i < transfer_token_op.length; i++){
                           if (transfer_token_op[i].id == uint256(id)){
                               for (uint256 j = 0; j < transfer_token_op[i].acceptors.length; j++){
                                   if (transfer_token_op[i].acceptors[j] == msg.sender){
                                       uint256 index = j;
                                       for (uint z = index; z < transfer_token_op[i].acceptors.length-1; z++){
                                           transfer_token_op[i].acceptors[z] = transfer_token_op[i].acceptors[z+1];
                                       }
                                       delete transfer_token_op[i].acceptors[transfer_token_op[i].acceptors.length-1];
                                       removeOperationAcceptor(uint256(id), msg.sender);
                                       transfer_token_op[i].acceptors.pop();
                                       emit CancelRegistered(id, msg.sender);
                                       break;
                                   }
                               }

                               if (transfer_token_op[i].acceptors.length == 0){
                                   transfer_token_op[i] = transfer_token_op[transfer_token_op.length - 1];
                                   transfer_token_op.pop();
                                   deleteOperation(uint256(id));
                                   emit ActionCanceled(id);
                                   break;
                               }
                           }
                       }
                   }
       }

       function confirm(bytes32 id) external isOwner {
               bytes32 o_type = opers_types[uint256(id)];
                   if (o_type == bytes32("ADD_OWNER")){
                       for (uint256 i = 0; i < owner_addition_op.length; i++){
                           if (owner_addition_op[i].id == uint256(id)){
                                   uint256 acceptors_count = 0;
                                   uint256 oper_id = i;
                                   uint256 global_id = uint256(id);

                                       oper_id = i;
                                       global_id = owner_addition_op[i].id;

                                       bool is_checlk_norm = true;
                                       for (uint256 j = 0; j < owner_addition_op[i].acceptors.length; j++){
                                           is_checlk_norm = is_checlk_norm && (owner_addition_op[i].acceptors[j] != msg.sender);
                                       }
                                       if (is_checlk_norm){
                                           owner_addition_op[i].acceptors.push(msg.sender);
                                           addOperationAcceptor(global_id, msg.sender);
                                           acceptors_count = owner_addition_op[i].acceptors.length;
                                           emit ActionConfirmed(bytes32(owner_addition_op[oper_id].id), msg.sender);
                                       }



                                   if (acceptors_count >= threshold && !isSenderOwner(owner_addition_op[oper_id].newowner)){
                                       owners.push(owner_addition_op[oper_id].newowner);
                                       deleteOperation(global_id);
                                       emit OwnerAdded(owner_addition_op[oper_id].newowner);
                                       owner_addition_op[oper_id] = owner_addition_op[owner_addition_op.length - 1];
                                       owner_addition_op.pop();

                                   }
                                   break;
                           }
                       }
                   }

                   if (o_type == bytes32("REMOVE_OWNER")){
                       uint256 acceptors_count = 0;
                       for (uint256 i = 0; i < owner_removing_op.length; i++){
                           if (owner_removing_op[i].id == uint256(id)){
                                  uint256 oper_id = i;
                           uint256 global_id = uint256(id);
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < owner_removing_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (owner_removing_op[i].acceptors[j] != msg.sender);
                           }
                           if (is_checlk_norm){
                               owner_removing_op[i].acceptors.push(msg.sender);
                               acceptors_count = owner_removing_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(owner_removing_op[oper_id].id), msg.sender);
                           }



                           if (acceptors_count >= threshold && (owners.length - 1) >= threshold){
                   deleteOperation(global_id);

                   for (uint256 j = 0; j < owners.length; j++){
                       if (owners[j] == owner_removing_op[oper_id].owner){
                           uint256 index = j;
                           for (uint i = index; i < owners.length-1; i++){
                               owners[i] = owners[i+1];
                           }
                           delete owners[owners.length-1];
                           owners.pop();
                           break;
                       }
                   }
                   emit OwnerRemoved(owner_removing_op[oper_id].owner);
                   owner_removing_op[oper_id] = owner_removing_op[owner_removing_op.length - 1];
                   owner_removing_op.pop();
               }


                               break;
                           }
                       }
                   }

                   if (o_type == bytes32("CHANGE_THRESHOLD")){
                       for (uint256 i = 0; i < threshold_changing_op.length; i++){
                           if (threshold_changing_op[i].id == uint256(id)){
                               uint256 acceptors_count = 0;
                               uint256 oper_id = i;
                               uint256 global_id = uint256(id);

                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < threshold_changing_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (threshold_changing_op[i].acceptors[j] != msg.sender);
                           }

                           if (is_checlk_norm){
                               threshold_changing_op[i].acceptors.push(msg.sender);
                               acceptors_count = threshold_changing_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(threshold_changing_op[oper_id].id), msg.sender);
                           }




                               if (acceptors_count >= threshold && threshold_changing_op[oper_id].value <= owners.length){

                   deleteOperation(global_id);

                   emit ThresholdChanged(owners.length, threshold, threshold_changing_op[oper_id].value);
                   threshold = threshold_changing_op[oper_id].value;
                   threshold_changing_op[oper_id] = threshold_changing_op[threshold_changing_op.length - 1];
                   threshold_changing_op.pop();
               }




                               break;
                           }
                       }
                   }

                   if (o_type == bytes32("TRANSFER")){
                       for (uint256 i = 0; i < transfer_eth_op.length; i++){
                           uint256 acceptors_count = 0;
                           if (transfer_eth_op[i].id == uint256(id)){
                           uint256 oper_id = i;
                           uint256 global_id = uint256(i);
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < transfer_token_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (transfer_token_op[i].acceptors[j] != msg.sender);
                           }
                           if (is_checlk_norm){
                               transfer_token_op[i].acceptors.push(msg.sender);
                               acceptors_count = transfer_token_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(transfer_token_op[oper_id].id), msg.sender);
                           }


                   if (acceptors_count >= threshold && address(this).balance >= transfer_eth_op[oper_id].value){
                   deleteOperation(global_id);

                   transfer_eth_op[oper_id].receiver.transfer(transfer_eth_op[oper_id].value);
                   emit TransferExecuted(address(0), transfer_eth_op[oper_id].receiver, transfer_eth_op[oper_id].value);
                   transfer_eth_op[oper_id] = transfer_eth_op[transfer_eth_op.length - 1];
                   transfer_eth_op.pop();
               }

                               break;
                           }
                       }
                   }

                   if (o_type == bytes32("TRANSFER_TOKEN")){
                       for (uint256 i = 0; i < transfer_token_op.length; i++){
                           if (transfer_token_op[i].id == uint256(id)){
                           uint256 acceptors_count = 0;
                                  uint256 oper_id = i;
                           uint256 global_id = transfer_token_op[i].id;
                           bool is_checlk_norm = true;
                           for (uint256 j = 0; j < transfer_token_op[i].acceptors.length; j++){
                               is_checlk_norm = is_checlk_norm && (transfer_token_op[i].acceptors[j] != msg.sender);
                           }
                           if (is_checlk_norm){
                               transfer_token_op[i].acceptors.push(msg.sender);
                               acceptors_count = transfer_token_op[i].acceptors.length;
                               addOperationAcceptor(global_id, msg.sender);

                               emit ActionConfirmed(bytes32(transfer_token_op[oper_id].id), msg.sender);
                           }


                           IERC20 tkn = IERC20(transfer_token_op[i].token);

                           if (acceptors_count >= threshold  && tkn.balanceOf(address(this)) >= transfer_token_op[oper_id].value){
                   deleteOperation(global_id);


                   tkn.transfer(transfer_token_op[oper_id].receiver, transfer_token_op[oper_id].value);
                   emit TransferExecuted(transfer_token_op[oper_id].token, transfer_token_op[oper_id].receiver, transfer_token_op[oper_id].value);
                                   transfer_token_op[oper_id] = transfer_token_op[transfer_token_op.length - 1];
                   transfer_token_op.pop();


               }

                               break;
                           }
                       }
                   }
       }

       function getUnconfirmed() public view isOwner returns (uint256[] memory) { // 0 means nothing, just skip it. Indexes to show needed to be minused by 1.
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

       function getUncompleted() public view isOwner returns (uint256[] memory) { // 0 means nothing, just skip it. Indexes to show needed to be minused by 1.
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


       function getAcceptorsCountById(uint256 oper_id) public view returns (uint256) {
           for (uint256 i = 0; i < global_opers.length; i++) {
               if (global_opers[i].id == oper_id) {
                   return global_opers[i].acceptors.length;
               }
           }

           return 0;
       }

       function getOwnerAdditions() public view returns (OwnerAddition[] memory) {
           return owner_addition_op;
       }

       function getOwnersRemovals() public view returns (OwnerRemoving[] memory) {
           return owner_removing_op;
       }

       function getThresholdChangings() public view returns (ThresholdChanging[] memory) {
           return threshold_changing_op;
       }

       function getTransferEthers() public view returns (TransferEth[] memory) {
           return transfer_eth_op;
       }

       function getTransferTokens() public view returns (TransferToken[] memory) {
           return transfer_token_op;
       }

       receive() payable external {}
   }
