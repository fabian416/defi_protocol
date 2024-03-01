// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StakingDFI {

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    address public owner;

    uint public duration;
    uint public finishAt;
    uint public updatedAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;
    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    uint256 public minVestingTime;
    uint256 public amountStaked;

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not the owner");
        _;
    }
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if(_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }
    constructor (address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = stakingToken;
    }
    
    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "Reward duration not finished");
        duration = _duration;
    }
    
    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)){
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(rewardRate * duration <= rewardToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp + duration;
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount equal 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);  
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns ( uint ) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (
            (lastTimeRewardApplicable()) - updatedAt) * 1e18
            ) / totalSupply; 
    }
    function earned(address _account) public view returns (uint) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18
         + rewards[_account];

    }

    function _min(uint x, uint y) private pure returns (uint) {
    return x <= y ? x : y;
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if(reward > 0 ) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

}