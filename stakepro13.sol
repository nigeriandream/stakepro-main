// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ILido {
    function totalSupply() external view returns (uint256);

    function submit(address _referral) external payable returns (uint256);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function allowance(
        address _owner,
        address _spender
    ) external returns (uint256);

    function balanceOf(address _account) external view returns (uint256);

    function unstake(uint256 _value) external returns (uint256);

    function getReward() external returns (uint256);

    function transfer(
        address _recipient,
        uint256 _amount
    ) external returns (bool);

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);
}

contract StakePro is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address lidoAddress = payable(0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F); // (0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILido public lido = ILido(lidoAddress); // integrate Lido interface
    uint256 public serviceFeePercentage;
    address public stakeProContract;
    address public owner;
    uint256 public stxApr;

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

    // mapping of admin addresses
    mapping(address => bool) public admins;

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 netReward,
        uint256 timestamp
    ); //@audit-ok - should include netReward

    constructor(
        uint256 _serviceFeePercentage,
        uint256 _stxApr
    ) payable ERC20("StakePro", "STX") {
        _mint(msg.sender, 1000000000000000000);
        require(_serviceFeePercentage <= 100, "Invalid service fee");
        owner = msg.sender;
        stakeProContract = payable(address(this));
        serviceFeePercentage = _serviceFeePercentage;
        stxApr = _stxApr;
    }

    //modifier to restrict usage to admins or contract owner
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "unauthorised");
        _;
    }

    // stake function
    function stake(
        uint256 _amount,
        uint256 _lockDuration // default to ZERO on UI, never blank
    ) public {
        // Get user data
        address _user = msg.sender;
        User storage user = id[_user];

        // Determine lock duration if not provided
        if (_lockDuration == 0 && user.locked) {
            _lockDuration = user.lockTime + user.lockDuration - block.timestamp;
        }

        // Convert ETH value to wei
        // uint256 _amount = msg.value;

        // Ensure amount is greater than 0
        require(_amount > 0, "Amount must be above zero");

        // Transfer ETH from user to Lido contract
        // lido.submit{value: _amount}(_user);

        // Transfer STX from user to StakePro
        _transfer(msg.sender, address(this), _amount);

        // Update user data
        user.stake = user.stake.add(_amount);
        user.events.push(Event(true, _amount, 0, block.timestamp));

        // Lock the user's tokens for the specified duration
        if (!user.locked && _lockDuration > 0) {
            user.locked = true;
            user.lockTime = block.timestamp;
            user.lockDuration = _lockDuration;
        }

        // Emit event
        emit Staked(_user, _amount, block.timestamp);
    }

    // unstake function
    function unstake() external payable {
        // Get user data
        address _user = payable(msg.sender);
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

        // Ensure user has staked
        require(user.stake > 0, "Nothing staked");

        // fetch amount
        uint256 _amount = user.stake;

        // Approve and verify allowance for stakepro to spend user tokens
        require(approve(address(this), 0), "Reset Allowance Failed");
        require(approve(address(this), _amount), "Approval failed");
        require(
            allowance(_user, address(this)) >= _amount,
            "Insufficient Allowance"
        );

        // Calculate rewards
        user.latestReward = getUserReward();
        uint256 serviceFee = user.latestReward.mul(serviceFeePercentage).div(
            100
        );
        uint256 netReward = user.latestReward.sub(serviceFee);
        user.lifetimeRewards = user.lifetimeRewards.add(user.latestReward);

        // Update user data
        user.stake = user.stake.sub(_amount);
        user.lastUnstake = block.timestamp;
        user.events.push(Event(false, _amount, netReward, block.timestamp));

        // claim rewards
        _mint(msg.sender, netReward);

        // Unstake tokens

        _transfer(address(this), msg.sender, _amount);

        // Emit event
        emit Unstaked(_user, _amount, netReward, block.timestamp);
    }

    function claim() public {
        // Get user data
        address _user = msg.sender;
        User storage user = id[_user];

        // ensure stake was placed
        require(user.stake > 0, "insufficient stake");

        uint256 userRewards = getUserReward();
        _mint(msg.sender, userRewards);
        user.lockTime = block.timestamp;
    }

    // funtion to let admin transfer contract ETH to specified address
    function transferEth(
        address payable recipient,
        uint256 _value
    ) public onlyAdmin {
        // Convert ETH value to wei
        uint256 amount = _value.mul(10 ** 18);

        require(address(this).balance >= amount, "Insufficient balance");
        recipient.transfer(amount);
    }

    // function to retrieve a user's staking and unstaking history
    function getUserHistory() external view returns (Event[] memory) {
        // Get user data
        address _user = msg.sender;
        User storage user = id[_user];

        Event[] memory events = user.events;
        uint256 eventsLength = events.length;
        Event[] memory result = new Event[](eventsLength);

        // iterate through the events array in reverse
        for (uint256 i = 0; i < eventsLength; i++) {
            result[i] = events[eventsLength.sub(i).sub(1)];
        }
        return result;
    }

    // view function to fetch rewards for a user
    function getUserReward() public view returns (uint256) {
        // Get user data
        address _user = msg.sender;
        User storage user = id[_user];

        // Calculate user latest reward
        uint256 reward = user.stake.mul(stxApr).mul(user.lockDuration).div(
            60 seconds
        );

        return reward;
    }

    //view function to fetch lifetime rewards for a user
    function getLifetimeRewards() external view returns (uint256) {
        // Get user data
        address _user = msg.sender;
        User storage user = id[_user];

        // Return lifetime rewards
        return user.lifetimeRewards;
    }

    function getCurrentStake() external view returns (uint256) {
        address _user = msg.sender;
        User storage user = id[_user];
        return user.stake;
    }

    function getWalletBalance() external view returns (uint256) {
        // Get user data
        address _user = payable(msg.sender);

        // Return user's wallet balance
        return (_user.balance);
    }

    function StakeproContractBalance() external view returns (uint256) {
        // Return user's wallet balance
        return stakeProContract.balance;
    }

    // function to let authorised users REGISTER admins
    function registerAdmin(address _newAdmin) public onlyAdmin {
        admins[_newAdmin] = true;
    }

    // function to let authorised users UNREGISTER admins
    function unregisterAdmin(address _admin) public onlyAdmin {
        require(admins[_admin], "Address is not an admin");
        admins[_admin] = false;
    }

    receive() external payable {}

    fallback() external payable {}
}
