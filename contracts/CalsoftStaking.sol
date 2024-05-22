//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
  @title CS Staking contract which helps to Deposit & Reward tokens
  @author hariprakash
  @notice Staking Pools, Deposit Token, Withdraw Tokens, Withdraw reward tokens,
 */
contract CalsoftStaking is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    string public constant name = "CS - Staking";

    // Total amount deposited on pool
    mapping(uint256 => uint256) public totalDepositAmountInPool;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Pool already created or not.
    mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => bool)) public hasPoolExist;
    // Rewards Earned by pool
    mapping(uint256 => mapping(address => uint256)) public rewardsEarned;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 depositStartTime; // Deposit start time in pool
        bool hasDeposited; // Check is account Deposited
        bool isDeposited; // Check is account currently deposited
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20MetadataUpgradeable depositToken; // Address of deposit token contract
        IERC20MetadataUpgradeable rewardToken; // Address of Reward token contract
        uint256 startTime; // Pool's start time (in seconds)
        uint256 endTime; // Pool's end time (in seconds)
        uint256 rewardInterval; // Reward interval (in seconds)
        uint256 rewardRate; // Reward rate in percentage (APR %)
    }
    event AddPool(
        uint256 poolId,
        IERC20MetadataUpgradeable depositToken,
        IERC20MetadataUpgradeable rewardToken,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardInterval,
        uint256 rewardRate
    );
    event Reward(address indexed from, address indexed to, uint256 amount);
    event Deposit(
        uint256 poolId,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event UpdateDepositEndTime(uint256 endTime);
    event WithdrawAll(address indexed user, uint256 pid, uint256 amount);
    event WithdrawRewardTokensFromPool(
        uint256 _pid,
        address indexed tokenAddress,
        address indexed _account,
        uint256 _amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public virtual initializer {
        // initializing
        __Pausable_init();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    /**
       @dev get pool length
       @return current pool length
    */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
       @dev get current block timestamp
       @return current block timestamp
    */
    function getCurrentBlockTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    /**
       @dev setting deposit pool end time
       @param _pid index of the array i.e pool id
       @param _endTime when deposit pool ends
    */
    function setPoolDepositEndTime(uint256 _pid, uint256 _endTime)
        external
        virtual
        onlyOwner
        whenNotPaused
    {
        require(
            _endTime >= block.timestamp,
            "EndTime must be greater than current timestamp"
        );
        poolInfo[_pid].endTime = _endTime;
        emit UpdateDepositEndTime(_endTime);
    }

    /** 
       @dev returns the total deposited tokens in pool and it is independent of the total tokens in pool keeps
       @param _pid index of the array i.e pool id
       @return total deposited amount in pool
    */
    function getTotalTokensDepositedInPool(uint256 _pid)
        external
        view
        returns (uint256)
    {
        return totalDepositAmountInPool[_pid];
    }

    /** 
       @dev returns the total depsited user tokens in pool and it is independent of the total tokens in pool keeps
       @param _pid index of the array i.e pool id
       @return user deposited balance in particular pool
    */
    function getUserDepositedTokensInPool(uint256 _pid)
        external
        view
        returns (uint256)
    {
        return userInfo[_pid][msg.sender].amount;
    }

    /**
       @dev Add a new pool. Can only be called by the owner.
       @param _depositToken user deposit token
       @param _rewardToken user rewarded token
       @param _startTime when pool starts
       @param _endTime when pool ends
       @param _rewardInterval reward interval between this reward interval in seconds
       @param _rewardRate (APR) in %
    */
    function addPool(
        IERC20MetadataUpgradeable _depositToken,
        IERC20MetadataUpgradeable _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rewardInterval,
        uint256 _rewardRate
    ) public onlyOwner whenNotPaused {
        _beforeAddPool(
            _depositToken,
            _rewardToken,
            _startTime,
            _endTime,
            _rewardRate
        );
        poolInfo.push(
            PoolInfo({
                depositToken: _depositToken,
                rewardToken: _rewardToken,
                startTime: _startTime,
                endTime: _endTime,
                rewardInterval: _rewardInterval,
                rewardRate: _rewardRate
            })
        );
        hasPoolExist[_depositToken][_rewardToken] = true;
        uint256 _poolId = poolInfo.length - 1;
        emit AddPool(
            _poolId,
            _depositToken,
            _rewardToken,
            _startTime,
            _endTime,
            _rewardInterval,
            _rewardRate
        );
    }

    /**
       @dev AddPool validations.
       @param _depositToken user deposit token
       @param _rewardToken user rewarded token
       @param _startTime when pool starts
       @param _endTime when pool ends
       @param _rewardRate (APR) in %
    */
    function _beforeAddPool(
        IERC20MetadataUpgradeable _depositToken,
        IERC20MetadataUpgradeable _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rewardRate
    ) internal virtual {
        require(
            _startTime >= block.timestamp,
            "OpeningTime must be greater than current timestamp"
        );
        require(
            _endTime >= _startTime,
            "Closing time cant be before opening time"
        );
        require(
            _rewardRate > 0,
            "Add Pool : Reward Rate(APR) in % Must be greater than 0"
        );
        // require(
        //     !hasPoolExist[_depositToken][_rewardToken],
        //     "Add Pool: Pair already created"
        // );
    }     /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be deposited with the specified _weiAmount
   */
  function _getTokenAmount(uint256 _weiAmount,uint256 decimal)
    internal pure returns (uint256)
  {
    if(decimal <= 18) {
      return _weiAmount / 10 ** (18-decimal);
    } else {
      return _weiAmount * 10 ** (decimal-18);
    }
  }
 function _getDepositTokenAmount(uint256 _weiAmount,uint256 decimal)
    internal pure returns (uint256)
  {
    if(decimal <= 18) {
      return _weiAmount * 10 ** (18-decimal);
    } else {
      return _weiAmount / 10 ** (decimal-18);
    }
  }
  
    /**
       @dev Deposit token's.
       @param _pid index of the array i.e pool id
       @param _amount deposit amount
    */
    function deposit(uint256 _pid, uint256 _amount)
        external
        virtual
        whenNotPaused
    {
        _beforeDeposit(_pid, _amount);
        UserInfo storage user = userInfo[_pid][msg.sender];
        //check if reward exist for this user if exist transfer it to the user
        (uint256 reward, ) = calculateReward(_pid, msg.sender);
        if (reward > 0) {
            uint256 rewardTokens = poolInfo[_pid].rewardToken.balanceOf(
                address(this)
            );
            require(
                rewardTokens > reward,
                "Withdraw: Not Enough Reward Balance"
            );
            SendRewardTo(_pid, reward, msg.sender);
        }
        bool transferStatus = poolInfo[_pid].depositToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (transferStatus) {
            // update user deposit balance in particular pool
            user.amount = user.amount + _amount;
            // update Contract deposit balance in pool
            totalDepositAmountInPool[_pid] += _amount;
            // save the time when they started staking in particular pool
            user.depositStartTime = block.timestamp;
            // update staking status in particular pool
            user.hasDeposited = true;
            user.isDeposited = true;
            emit Deposit(_pid, msg.sender, address(this), _amount);
        }
    }

    /**
       @dev Deposit validations.
       @param _pid index of the array i.e pool id
       @param _amount deposit amount
    */
    function _beforeDeposit(uint256 _pid, uint256 _amount) internal virtual {
        require(_amount > 0, "Deposit: Amount cannot be 0");
        require(_pid <= poolInfo.length, "Deposit: Pool not exist");
        require(
            poolInfo[_pid].depositToken.balanceOf(msg.sender) >= _amount,
            "Deposit: Insufficient deposit token balance"
        );
        require(
            block.timestamp >= poolInfo[_pid].startTime,
            "Deposit: Pool not yet started"
        );
        require(
            block.timestamp <= poolInfo[_pid].endTime,
            "Deposit: Pool Ended"
        );
    }

    /**
       @dev calculateReward() function returns the reward of the caller of this function
       @param _pid index of the array i.e pool id
       @param _rewardAddress find how much reward in this address
       @return rewards and timedifference
    */
    function calculateReward(uint256 _pid, address _rewardAddress)
        public
        view
        returns (uint256, uint256)
    {
        UserInfo storage user = userInfo[_pid][_rewardAddress];
        uint256 balances = user.amount;
        uint256 rewards = 0;
        uint256 timeDifferences = 0;
        if (balances > 0) {
            uint256 _userBalance = _getDepositTokenAmount(balances , poolInfo[_pid].depositToken.decimals());
            uint256 tokens = _getTokenAmount(_userBalance,poolInfo[_pid].rewardToken.decimals());
            if (poolInfo[_pid].endTime > 0) {

                require(user.depositStartTime < poolInfo[_pid].endTime, "Pool ended , reward claimed already");

                if (block.timestamp > poolInfo[_pid].endTime) {
                    timeDifferences =
                        poolInfo[_pid].endTime -
                        user.depositStartTime;
                } else {
                    timeDifferences = block.timestamp - user.depositStartTime;
                }
            } else {
                timeDifferences = block.timestamp - user.depositStartTime;
            }

            rewards = ((tokens *
                poolInfo[_pid].rewardRate *
                timeDifferences) /
                ((1 * 10**4) * poolInfo[_pid].rewardInterval));
        }
        return (rewards, timeDifferences);
    }

    /**
       @dev function used to claim only the reward for the caller of the method
       @param _pid index of the array i.e pool id
    */
    function claimMyReward(uint256 _pid) external nonReentrant whenNotPaused {
        require(_pid <= poolInfo.length, "Withdraw: Pool not exist");
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            block.timestamp >= user.depositStartTime,
            "Withdraw: Withdraw reward tokens after next Reward Interval"
        );
        require(
            user.isDeposited,
            "Withdraw: No deposited token balance available"
        );
        uint256 balance = user.amount;
        require(balance > 0, "Withdraw: Balance cannot be 0");
        (uint256 reward, uint256 timeDifferences) = calculateReward(
            _pid,
            msg.sender
        );
        require(reward > 0, "Withdraw: Calculated Reward zero");
        require(
            timeDifferences / poolInfo[_pid].rewardInterval >= 1,
            "Withdraw: Can be claimed only after the interval"
        );
        uint256 rewardTokens = poolInfo[_pid].rewardToken.balanceOf(
            address(this)
        );
        require(rewardTokens > reward, "Withdraw: Not Enough Reward Balance");
        bool claimRewardStatus = SendRewardTo(_pid, reward, msg.sender);

        require(claimRewardStatus, "Withdraw: Claim Reward Failed");
        //depositStartTime (set to current time)
        user.depositStartTime = block.timestamp;
    }

    /**
       @dev check if the reward token is same as the deposited token
         If deposited token and reward token is same then -
         Contract should always contain more or equal tokens than deposited tokens
       @param _pid index of the array i.e pool id
       @param calculatedReward reward send to caller
       @param _toAddress caller address got reward
    */
    function SendRewardTo(
        uint256 _pid,
        uint256 calculatedReward,
        address _toAddress
    ) internal virtual returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];
        require(_toAddress != address(0), "Withdraw: Address cannot be zero");
        require(
            pool.rewardToken.balanceOf(address(this)) >= calculatedReward,
            "Withdraw: Not enough reward balance"
        );
        if (pool.depositToken == pool.rewardToken) {
            if (
                (pool.rewardToken.balanceOf(address(this)) - calculatedReward) <
                totalDepositAmountInPool[_pid]
            ) {
                calculatedReward = 0;
            }
        }
        bool successStatus = false;
        if (calculatedReward > 0) {
            uint256 transferAmount = calculatedReward;
            calculatedReward = 0;
            bool transferStatus = pool.rewardToken.transfer(
                _toAddress,
                transferAmount
            );
            require(transferStatus, "Withdraw: Transfer Failed");
            // if (userInfo[_pid][_toAddress].amount == 0) {
            //     userInfo[_pid][_toAddress].isDeposited = false;
            // }
            rewardsEarned[_pid][_toAddress] += transferAmount;
            // oldReward[_toAddress] = 0;
            //emit Reward(address(this), _toAddress, calculatedReward);
            successStatus = true;
        }
        return successStatus;
    }

    /**
       @dev Emergency withdraw all deposited tokens and reward tokens
       @param _pid index of the array i.e pool id
     */
    function withdrawAll(uint256 _pid) external whenNotPaused {
        uint256 reward;
        require(_pid <= poolInfo.length, "WithdrawAll: Pool not exist");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            block.timestamp >= user.depositStartTime,
            "Withdraw: Withdraw reward tokens after next Reward Interval"
        );
        require(user.amount > 0, "WithdrawAll: Not enough reward balance");

        if(user.depositStartTime < pool.endTime){
        (reward, ) = calculateReward(_pid, msg.sender);
        }

        uint256 amount = user.amount;
        user.amount = 0;
        user.isDeposited = false;
        if (reward > 0) {
            uint256 rewardTokens = poolInfo[_pid].rewardToken.balanceOf(
                address(this)
            );
            require(
                rewardTokens > reward,
                "WithdrawAll: Not Enough Reward Balance"
            );
            bool rewardSuccessStatus = SendRewardTo(_pid, reward, msg.sender);
            require(rewardSuccessStatus, "WithdrawAll: Claim Reward Failed");
        }
        pool.depositToken.safeTransfer(address(msg.sender), amount);
        emit WithdrawAll(msg.sender, _pid, amount);
    }

    /**
       @dev Withdraw reward tokens from particular pool
       @param _pid index of the array i.e pool id
     */
    function withdrawRewardTokensFromPool(uint256 _pid, uint256 _amount)
        external
        onlyOwner
        nonReentrant
    {
        poolInfo[_pid].rewardToken.safeTransfer(msg.sender, _amount);
        emit WithdrawRewardTokensFromPool(
            _pid,
            address(poolInfo[_pid].rewardToken),
            msg.sender,
            _amount
        );
    }
}
