//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

//staking contact - base currency + reward token

//1 - timeBeforeYouCanDeposit/timeWhenYouCanWithdraw is not initiated
//2 - timeBeforeYouCanDeposit should be less than timeWhenYouCanWithdraw
//3 - time is greater than timeBeforeYouCanDeposit
//4 - time shold be greater than timeWhenYouCanWithdraw
//5 - you have zero balance

//12 - not enough on balance
//13 - transfer failed


contract Ownable
{

  /**
   * @dev Error constants.
   */
  string public constant NOT_CURRENT_OWNER = "018001";
  string public constant CANNOT_TRANSFER_TO_ZERO_ADDRESS = "018002";

  /**
   * @dev Current owner address.
   */
  address public owner;
  address public ownAddress;

  /**
   * @dev An event which is triggered when the owner is changed.
   * @param previousOwner The address of the previous owner.
   * @param newOwner The address of the new owner.
   */
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  /**
   * @dev The constructor sets the original `owner` of the contract to the sender account.
   */
  constructor(){
    owner = msg.sender;
    ownAddress = address(this);
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner()
  {
    _isOwner();
    _;
  }
  
  function _isOwner() internal view
  {
    require(msg.sender == owner, NOT_CURRENT_OWNER);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(
    address _newOwner
  )
    public
    onlyOwner
  {
    require(_newOwner != address(0), CANNOT_TRANSFER_TO_ZERO_ADDRESS);
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }

}

contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor ()  {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _isNonReentrant();
        _;    
    }

    function _isNonReentrant() internal 
    {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        require(localCounter == _guardCounter, "22");
    }
}




/**
 * @dev signature of external (deployed) contract (ERC20 token)
 * only methods we will use
 */
interface ERC20Token {
 
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals()  external view returns (uint8);
  
}

contract StakingContract is Ownable, ReentrancyGuard {

    uint256 public timeBeforeYouCanDeposit;
    uint256 public timeWhenYouCanWithdraw;
    uint256 public sharedRewardAmount;
    uint256 public totalDepositsAmount;
    uint256 public scale = 1e5;

    address public rewardToken;
  
    function setTimeBeforeYouCanDeposit(uint256 newValue) external onlyOwner {
        timeBeforeYouCanDeposit = newValue;
    }

    function setTimeWhenYouCanWithdraw(uint256 newValue) external onlyOwner {
        timeWhenYouCanWithdraw = newValue;
    }

    function setSharedRewardAmount(uint256 newValue) external onlyOwner {
        sharedRewardAmount = newValue;
    }    

    function setRewardToken(address token) external onlyOwner {
        rewardToken = token;
    }  

    function onwerWithdrawTokens(address tokenAddress, uint256 realAmountTokens) external onlyOwner{
         
        ERC20Token token = ERC20Token(tokenAddress);
       
       
        uint256 contractTokenBalance = token.balanceOf(ownAddress);
        
        // if 0 - it means we withdraw max amount
        if (realAmountTokens == 0) realAmountTokens = contractTokenBalance;
      
        require(contractTokenBalance >= realAmountTokens, "12"); 
        //if (contractTokenBalance < realAmountTokens) {
        //    revert InsufficientBalance();
        //}
       
        //ensure we revert in case of failure 
        try token.transfer(owner, realAmountTokens) returns (bool result) { 
            require(result,"13");
            //just continue if all good..
        } catch {
            require(false,"13");
           
        }
             
      
    }

    //customer address -> amount
    mapping (address => uint256)  public customersDeposits;

    
    function deposit() external payable {
        require(timeBeforeYouCanDeposit != 0, "1");
        require(timeBeforeYouCanDeposit < timeWhenYouCanWithdraw, "2");
        require(block.timestamp <  timeBeforeYouCanDeposit, "3");
        customersDeposits[msg.sender] += msg.value;
        totalDepositsAmount += msg.value;
    }

    function withdraw() external nonReentrant {
        require(timeWhenYouCanWithdraw != 0, "1"); 
        require(block.timestamp > timeWhenYouCanWithdraw, "4");
        require(customersDeposits[msg.sender] >0, "5");

        //sending ether
        bool success = false;
        // ** sendTo.transfer(amount);** 
        (success, ) = (payable(msg.sender)).call{value:  customersDeposits[msg.sender] }("");
        require(success, "13");

        //calc reward
        //need to be verified, possibly floatin point library need be used in general case
        //curretnly we account on ERC20 with 18 digits
        uint256 reward = (sharedRewardAmount * customersDeposits[msg.sender]) / totalDepositsAmount;

        ERC20Token token = ERC20Token(rewardToken);
       
       
        uint256 contractTokenBalance = token.balanceOf(ownAddress);
        
       
        require(contractTokenBalance >= reward, "12"); 
        
        //ensure we revert in case of failure 
        try token.transfer(msg.sender, reward) returns (bool result) { 
            require(result,"13");
            //just continue if all good..
        } catch {
            require(false,"13");
           
        }

        customersDeposits[msg.sender] = 0;
        
    }


}


