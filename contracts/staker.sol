// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
 import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 import "hardhat/console.sol";


contract FixedStaking is ERC20 {

mapping(address=>uint256) public staked;
mapping(address=>uint256) public stakedfromTS;

constructor() ERC20 ("Fixed Staking", "FIX")  { // Token description
        
        //  uint constant _initial_supply= 10**18;  Initial deposit in creators wallet 

        _mint(msg.sender, 10**18);
          console.log( "Balance: ", balanceOf(msg.sender) );

    }
function stake(uint256 amount)external{

                require(amount>0, "amount <= 0");
                require(balanceOf(msg.sender)>=amount, "Balance is not enough");
                _transfer(msg.sender, address(this), amount);

                if(staked[msg.sender]>0){
claim();
                }
                stakedfromTS[msg.sender] = block.timestamp;
                staked[msg.sender] += amount;

                 }

         function unstake(uint256 amount)external{        
                require(amount>0, "amount <= 0");
                require(staked[msg.sender]>=amount, "amount > staked");
            
                claim();
                 staked[msg.sender] -= amount;
               _transfer(address(this), msg.sender, amount);
              
         }


          function claim() public{        
                require(staked[msg.sender]>0, "staked is <= 0");
                uint256 secondsStaked = block.timestamp - stakedfromTS[msg.sender];
                uint256 rewards = staked[msg.sender] * secondsStaked / 60;            
                _mint(msg.sender, rewards);
                stakedfromTS[msg.sender] = block.timestamp;
              
         }
}