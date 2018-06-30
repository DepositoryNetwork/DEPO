pragma solidity ^0.4.24;

contract Depository {
    uint constant neededConfirmations = 6;

    address private bankAddress;
    address private arbiterAddress;
    uint private collateralAmount;
    address private client;

    uint depositBlockNumber;

    bool private amountLocked = true;
    bool private liquidationRequested = false;
    bool private completed = false;
    bool private amountDeposited = false;

    address private liquidationAddress;

    event MoneyDeposited(uint amount);
    event WithdrawMoney(uint amount);

    /*
    *   Checks if the Deposited Amount is unlocked.
    */
    modifier amountUnlocked() {
        require(amountLocked == false);
        _;
    }
    /*
    *   Makes sure that the contract is in Liquidation state.
    */
    modifier liquidationBegun() {
        require(liquidationRequested);
        _;
    }
    /*
    *   Makes sure that the msg.sender is the Client.
    */
    modifier isClient() {
        require(client == msg.sender);
        _;
    }
    modifier notInLiqudation() {
        require(liquidationRequested == false);
        _;
    }
    /*
    *   Makes sure that the msg.sender is the Arbiter.
    */
    modifier isArbiter() {
        require(arbiterAddress == msg.sender);
        _;
    }
    /*
    *   Makes sure that the msg.sender is the Bank.
    */
    modifier isBank() {
        require(msg.sender == bankAddress);
        _;
    }
    /*
    *   Makes sure that the you can deposit only once.
    */
    modifier waitingDeposit() {
        require(amountDeposited == false);
        _;
    }

    constructor(address _arbiterAddress, uint _collateralAmount) public {
        bankAddress = tx.origin;
        arbiterAddress = _arbiterAddress;
        collateralAmount = _collateralAmount;
    }

    /*
    * For the PoC we require that the amount send is over the collateralAmount
    * that is required. This can be done smarter for main product.
    */
    function deposit() public waitingDeposit payable {
        require(msg.value >= collateralAmount);
        depositBlockNumber = block.number;
        client = msg.sender;
        amountLocked = true;
        amountDeposited = true;
        emit MoneyDeposited(msg.value);
    }

    /*
    * Used by the Bank to unlock the Ether after the Client has paid his loan.
    */
    function unLock() public isBank {
        amountLocked = false;
    }

    /*
    * The Client can withdraw his money to an specific address after the loan is paid.
    * Requires the amount to be unlocked (The bank to have specified that the user paid)
    * TODO: We need to figure out if we want to use ".transfer" as this can be made
    *       to revert() permanently.
    */
    function withdraw(address _recipientAddress) public isClient amountUnlocked notInLiqudation {
        address(_recipientAddress).transfer(collateralAmount);
        completed = true;
        emit WithdrawMoney(collateralAmount);
    }

    /*
    * The Bank requests Liquidation as the Client has probably not paid his loan.
    * The Bank needs to provide an address where the money should be sent.
    */
    function requestLiquidation(address _recipientAddress) public isBank {
        require(amountLocked);
        liquidationRequested = true;
        liquidationAddress = _recipientAddress;
    }

    /*
    * Arbiter need to Approve the Liquidation process. If he does the money address
    * sent to the address that is provided by the bank.
    */
    function approveLiquidation() public isArbiter liquidationBegun {
        address(liquidationAddress).transfer(address(this).balance);
        liquidationRequested = false;
        completed = true;
    }
    /*
    * Returns the Confirmation status. This is based on the neededConfirmations
    */
    function getConfirmationStatus() view public returns(bool) {
        return depositBlockNumber + neededConfirmations <= block.number;
    }
    /*
    * Returns the Liquidation status.
    * Used to display to the Arbiter if his action is needed.
    */
    function inLiquidation() view public returns(bool) {
        return liquidationRequested;
    }
    /*
    * Returns the collateral Amount to display to the Client how much they need to deposit
    */
    function getNeededAmount() view public returns(uint) {
        return collateralAmount;
    }
    /*
    * Returns all the Status data that is needed for the Web interface to display.
    */
    function getStatusData() view public returns(uint amount, bool paymentStatus, bool inDispute, bool isCompleted) {
        return(collateralAmount, depositBlockNumber > 0, liquidationRequested, completed);
    }
    /*
    * Returns if the caller is an Arbiter. To show only contract available to him.
    */
    function arbiterCheck() view public isArbiter returns(bool) {
        return true;
    }

    /*
    * Checks if the Client is able to withdraw
    */
    function ableToWithdraw() view public amountUnlocked notInLiqudation returns(bool) {
        return true;
    }
    /*
    * Checks if the User is able to deposit or he already deposit the money.
    */
    function abletoDeposit() view public waitingDeposit returns(bool) {
        return true;
    }


}

contract DepositoryFactory {

    address private bankAddress;

    address[] private depositories;

    mapping(address => uint) arbiterContractsCount;

    /*
    * TODO: Remove this and hardcode the address of the bankAddress
    *       We use this in dev to setup faster when re deploying
    */
    constructor() public {
        bankAddress = msg.sender;
    }
    /*
    * Makes sure that the msg.sender is actually the Bank.
    */
    modifier isBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /*
    * TODO: Figure out do we want to pass arbiterAddress for every single
    *       new Depository or just hardcode that aswell
    */
    function createDepo(address _arbiterAddress, uint _collateralAmount) public isBank {
        depositories.push(new Depository(_arbiterAddress, _collateralAmount));
        arbiterContractsCount[_arbiterAddress]++;
    }
    /*
    * Returns all the Depositories created by this Factory.
    */
    function getAllDepositories() view public returns (address[]) {
        return depositories;
    }
    /*
    * Returns the count of the contracts that, a user is Arbiter for.
    */
    function getArbiterContractCount() view public returns(uint) {
        return arbiterContractsCount[msg.sender];
    }

}
