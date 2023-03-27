// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ILido.sol";

// import "@lido/dao/contracts/0.4.24/Lido.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

contract StakePro is ReentrancyGuard, ILido {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ILido public lido = ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    uint256 public serviceFeePercentage;
    address public lidoContract; // staked ETH contract address
    address public stakeProContract;
    address public owner;

    // struct to express user data
    struct User {
        uint256 stake;
        uint256 lastUnstake;
        uint256 latestReward;
        uint256 lifetimeRewards;
        uint256 lockTime;
        uint256 lockDuration;
        bool locked;
        Event[] events;
        // add other relevant information here
    }

    // struct to store staking and unstaking events
    struct Event {
        bool isStake;
        uint256 amount;
        uint256 rewards;
        uint256 timestamp;
    }

    // mapping of user addresses to their data
    mapping(address => User) public id;

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 netReward,
        uint256 timestamp
    ); //@audit-ok - should include netReward

    constructor(uint256 _serviceFeePercentage) {
        require(_serviceFeePercentage <= 100, "Invalid service fee");

        owner = msg.sender;
        stakeProContract = address(this);
        serviceFeePercentage = _serviceFeePercentage;
    }

    // stake function
    function stakeETH(
        uint256 _amount,
        address _user, //@audit - remember to determine user input for this function
        uint256 _lockDuration // only valid when lock is inactive (grey out on UI if `locked` = true)
    ) external payable nonReentrant {
        // Get user data
        _user = msg.sender;
        User storage user = id[_user];

        // Ensure amount is greater than 0
        require(_amount > 0, "must be above zero");

        // Ensure user has sufficient balance
        require(lido.balanceOf(_user) > _amount, "Insufficent Balance");

        // Approve and verify allowance for stakepro to spend user tokens
        require(lido.approve(address(this), 0), "Reset Allowance Failed");
        require(lido.approve(address(this), _amount), "Approval failed");
        require(
            lido.allowance(_user, address(this) == _amount),
            "Insufficient Allowance"
        );

        // Update user data
        user.stake = user.stake.add(_amount);
        user.events.push(Event(true, _amount, 0, block.timestamp));

        // Transfer tokens from user wallet to contract
        require(lido.transfer(address(this), _amount), "Token transfer failed");

        // Stake transferred tokens directly using Lido contract
        lido.submit{value: _amount}(address(0));
        lido.stake(_amount, address(0));

        // Lock the user's tokens for the specified duration
        if (!user.locked) {
            user.locked = true;
            user.lockTime = block.timestamp;
            user.lockDuration = _lockDuration;
        }

        // Emit event
        emit Staked(_user, _amount, block.timestamp);
    }

    // unstake function
    function unstake(address _user) external nonReentrant {
        // Get user data
        _user = msg.sender;
        User storage user = id[_user];

        // Check if lock duration has expired
        if (block.timestamp > user.lockTime + user.lockDuration) {
            // Unlock the user's tokens and reset lock
            user.locked = false;
            user.lockTime = 0;
            user.lockDuration = 0;
        } //@audit-ok configure time-lock

        // check if user stakes are unlocked
        require(!user.locked, "stakes are locked");

        // fetch amount
        uint256 _amount = user.stake;

        // Ensure user has staked
        require(user.stake > 0, "Nothing staked");

        // Ensure user has enough stake
        // require(user.stake >= _amount, "insufficient stake");

        // Calculate rewards
        user.latestReward = getReward();
        uint256 serviceFee = user.latestReward.mul(serviceFeePercentage).div(
            100
        );
        uint256 netReward = user.latestReward.sub(serviceFee);
        user.lifetimeRewards = user.lifetimeRewards.add(user.latestReward);

        // Update user data
        user.stake = user.stake.sub(_amount);
        user.lastUnstake = block.timestamp;
        user.events.push(Event(false, _amount, netReward, block.timestamp));

        // Unstake tokens from Lido
        lido.unstake(_amount);

        // Transfer tokens back to user wallet
        require(lido.transfer(_user, _amount), "Token transfer failed");

        // Emit event
        emit Unstaked(_user, _amount, netReward, block.timestamp);
    }

    // function to retrieve a user's staking and unstaking history
    function getUserHistory(
        address _user
    ) external view returns (Event[] memory) {
        // Get user data
        _user = msg.sender;
        User storage user = id[_user];

        Event[] memory events = user.events;
        uint eventsLength = events.length;
        Event[] memory result = new Event[](eventsLength);

        // iterate through the events array in reverse
        for (uint i = 0; i < eventsLength; i++) {
            result[i] = events[eventsLength.sub(i).sub(1)];
        }
        return result;
    }

    // view function to fetch rewards for a user
    function getReward() internal returns (uint256) {
        // Call getReward function from Lido contract
        return lido.getReward();
    }
}
