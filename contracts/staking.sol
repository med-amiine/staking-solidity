// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";

contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner ;
    uint public duration;
    uint public finishAt;
    uint public updateAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;
    mapping (address => uint) public userRewardPerTokenPaid;
    mapping (address => uint) public rewards;

    uint public totalSupply;
    mapping (address => uint) public balanceOf;

    modifier onlyOwner() {
        require(msg.sender == owner,"not owner");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updateAt = lastTimeRewardApplicable();

        if (_account != address(0)){
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    constructor(address _stakingToken, address _rewardsToken){
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(block.timestamp > finishAt , "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardsAmount(uint _amount) external onlyOwner updateReward(address(0)){
        if (block.timestamp > finishAt){
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require (rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );
        finishAt = block.timestamp + duration;
        updateAt = block.timestamp;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount); 
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        if (balanceOf[msg.sender] > _amount) {
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transferFrom(address(this), msg.sender, _amount); 
        }
    }

    function lastTimeRewardApplicable() public view returns (uint){
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * 
            ( lastTimeRewardApplicable() - updateAt * 1e18
            ) / totalSupply);
    }

    function earned(address _account) public view returns (uint) {
        return (balanceOf[_account] * 
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18
         + rewards[_account];
    }
    function getreward() external updateReward(msg.sender){
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transferFrom(address(this), msg.sender, reward);
        }
    }


    function _min(uint a,uint b) private pure returns (uint) {
        return a <= b ? b : a;
    }


}