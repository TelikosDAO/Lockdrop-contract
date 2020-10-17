// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import './interfaces/ITelikos.sol';

contract Lock {
    // address owner; slot #0
    // address unlockTime; slot #1
    constructor (address owner, uint256 unlockTime) public payable {
        assembly {
            sstore(0x00, owner)
            sstore(0x01, unlockTime)
        }
    }

    /**
    * @dev        Withdraw function once timestamp has passed unlock time
    */
    receive () external payable {
        uint256 _balance = address(this).balance;
        uint256 _timestamp = block.timestamp;
        assembly {
            switch gt(_timestamp, sload(0x01))
            case 0 { revert(0, 0) }
            case 1 {
                switch call("gas", sload(0x00), _balance, 0, 0, 0, 0)
                case 0 { revert(0, 0) }
            }
        }
    }
}

contract Lockdrop {
    using SafeMath for uint256;
    // Time constants
    uint constant public LOCK_DROP_PERIOD = 30 days;
    uint public LOCK_START_TIME;
    uint public LOCK_END_TIME;
    address public telikos;
    address public admin;

    // ETH locking events
    event Locked(uint256 eth, uint256 tek, uint256 indexed duration, address lock, address indexed owner);
    event Step(string step);

    constructor(uint startTime) public {
        LOCK_START_TIME = startTime;
        LOCK_END_TIME = startTime + LOCK_DROP_PERIOD;
        admin = msg.sender;
    }

    function setTelikos(address _telikos) external {
        require(admin == msg.sender, "Only admin can set the Telikos Address");
        require(telikos == address(0), "You can only set the address once.");
        telikos = _telikos;
    }
    /**
     * @dev        Locks up the value sent to contract in a new Lock
     * @param      _days         The length of the lock up
     */
    function lock(uint256 _days)
        external
        payable
        returns (address){
        //Require the lockdrop has started and not ended.
        require(now >= LOCK_START_TIME);
        require(now <= LOCK_END_TIME);
        
        // Accept External Owned Accounts only
        require(msg.sender == tx.origin, "Sender not original");

        // Accept only fixed set of durations
        require(
            _days == 30 ||
            _days == 45 ||
            _days == 60 ||
            _days == 90 ||
            _days == 120 ||
            _days == 180, 
                "Days not correct"
        ); 
        uint unlockTime = now + _days * 1 days;
        uint256 reward = calculateReward(msg.value, _days);
        // Accept non-zero payments only
        require(msg.value > 0, "Value less than 0");
        uint256 eth = msg.value;

        // Create ETH lock contract
        Lock lockAddr = (new Lock).value(eth)(msg.sender, unlockTime);

        // ensure lock contract has all ETH, or fail
        assert(address(lockAddr).balance >= eth);
        ITelikos tek = ITelikos(telikos);
        tek.mint(msg.sender, reward);
        emit Locked(
            eth,
            reward,
            _days,
            address(lockAddr),
            msg.sender
        );
        return address(lockAddr);
    }

    /**
     * @dev Calculate rewards based on dates.
     */

    function calculateReward(uint256 eth, uint _days) public pure returns (uint256)
    {   return eth.mul(25).mul(_days);
    }
}
