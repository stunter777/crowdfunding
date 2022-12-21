//SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.0;
import 'contracts/IERC20.sol';

contract Crowd {
    struct Campaign {
        address owner;
        uint goalfunds;
        uint pledged;
        uint startAt;
        uint endsAt;
        bool claimed;
    }
    IERC20 public immutable token;
    mapping(uint => Campaign) campaigns;
    uint public currentID;
    mapping(uint => mapping(address => uint)) public pledges;
    uint public constant MAX_DURATION = 100 days;
    uint private constant MIN_DURATION = 10;

    event Launched(uint ID,address owner,uint goal,uint startsAt,uint endsAt);
    event Pledged(uint _id,address pledger,uint _amount);
    event Unpledged(uint _id,address pledger,uint _amount);
    event Claimed(uint _id);
    event Refunded(uint _id,address pledger,uint pledgedAmount);

    constructor(address _token){
        token = IERC20(_token);
    }

    function launch(uint _goal, uint _startsAt,uint _endsAt) external {
        require(_startsAt >= block.timestamp, "incorrect start");
        require (_endsAt >= _startsAt +  MIN_DURATION, "incorrect end");
        require (_endsAt <= _startsAt + MAX_DURATION, "too long!");

        campaigns[currentID] = Campaign ({
            owner:msg.sender,
            goalfunds: _goal,
            pledged: 0,
            startAt: _startsAt,
            endsAt:_endsAt,
            claimed: false
        });

        emit Launched(currentID,msg.sender,_goal,_startsAt,_endsAt);
        currentID += 1;
    }
    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.owner, "not an owner!");
        require(block.timestamp < campaign.startAt,"TRYNA FOOL ME?");
        
        delete campaigns[_id];
    }
    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not Started!");
        require(block.timestamp < campaign.endsAt, "ended!");

        campaign.pledged += _amount;
        pledges[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender,address(this),_amount);
        emit Pledged(_id,msg.sender,_amount);
    }
    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp < campaign.endsAt, "ended");

        campaign.pledged -= _amount;
        pledges[_id][msg.sender] -= _amount;
        token.transfer(msg.sender,_amount);
        emit Unpledged(_id, msg.sender,_amount);
    }
    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.owner,"not an owner!");
        require(block.timestamp > campaign.endsAt,"not ended!");
        require(campaign.pledged >= campaign.goalfunds, "pledged too low!");
        require(campaign.claimed,"already claimed");
        campaign.claimed = true;
        token.transfer(msg.sender,campaign.pledged);
        emit Claimed(_id);

    }
    function refund(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endsAt,"not ended!");
         require(campaign.pledged < campaign.goalfunds, "reached the goal!!");
         uint pledgedAmount = pledges[_id][msg.sender];
         pledges[_id][msg.sender] = 0;
         token.transfer(msg.sender,pledgedAmount);
         emit Refunded(_id,msg.sender,pledgedAmount);
    }
}