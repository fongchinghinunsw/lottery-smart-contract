// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    using SafeMath for uint256;

    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    // we need to pull the USD/ETH price from price feed to convert USD to ETH
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lottery_state;

    uint256 public fee;
    // identifies the chainlink VRF node
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId);

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
    }

    // people can enter the lottery by paying ETH using this function
    function enter() public payable {
        require(
            lottery_state == LOTTERY_STATE.OPEN,
            "A new round of lottery is not open yet, please try again later."
        );
        // the minimum fee to participate in the lottery is USD $50
        require(
            msg.value >= getEntranceFee(),
            "Not enough ETH to enter the lottery! You need at least USD $50."
        );
        // add the player to the list of all participates
        players.push(msg.sender);
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "The current round of lottery is still in progress, can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestedRandomness(requestId);
    }

    // get the entrance fee of the lottery in Wei
    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        // the price feed we are using has 8 decimals, we can multiply it by 10 ** 10 so that it
        // the price will be the right amount in USD.
        uint256 adjustedPrice = uint256(price * 10**10);
        // the 18 decimals in the dominator and the numberator will cancel out
        // the resulting formula will be (50 / real USD price) * 10**18
        uint256 costToEnter = SafeMath.div(
            SafeMath.mul(usdEntryFee, 10**18),
            adjustedPrice
        );
        return costToEnter;
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "Still calculating the winner!"
        );

        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        // transfer all the ETH in this contract to the winner
        recentWinner.transfer(address(this).balance);
        // Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
    }
}
