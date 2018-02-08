pragma solidity ^0.4.19;
import "./SafeMath.sol";
import "./Ownable.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale is Ownable{
  using SafeMath for uint256;

  // The token being sold
  ZNAQToken public token;
  
  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei
  uint256 public rate;

  // amount of raised money in wei
  uint256 public weiRaised;

  // Company addresses
  address public TeamAndAdvisors;
  address public Company;
  address public MarketingNetworkGrowth;
  address public Bounty;
  // Percent
  uint256 rate15 = 15;
  uint256 rate10 = 10;
  uint256 rate5 = 5;

  uint256 discountValue = 0;
  uint256 discountStage1;
  uint256 discountStage2;
  uint256 discountStage3;
  uint256 discountStage4;
  uint256 discountStage5;
  modifier saleIsOn() {
      require(now > startTime && now < endTime);
      _;
  }

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event TokenPartners(address indexed purchaser, address indexed beneficiary, uint256 amount);

  function Crowdsale(
    uint256 _startTime,
    uint256 _endTime,
    uint256 _rate,
    address _wallet,
    address _TeamAndAdvisors,
    address _Company,
    address _MarketingNetworkGrowth,
    address _Bounty,
    uint256 _discountStage1,
    uint256 _discountStage2,
    uint256 _discountStage3,
    uint256 _discountStage4,
    uint256 _discountStage5) public {
    require(_endTime > _startTime);
    require(_rate > 0);
    require(_wallet != address(0));
    require(_TeamAndAdvisors != address(0));
    require(_Company != address(0));
    require(_MarketingNetworkGrowth != address(0));
    require(_Bounty != address(0));
    token = createTokenContract();
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = _wallet;
    MarketingNetworkGrowth = _MarketingNetworkGrowth;
    TeamAndAdvisors = _TeamAndAdvisors;
    Company = _Company;
    Bounty = _Bounty;
    discountStage1 = _discountStage1;
    discountStage2 = _discountStage2;
    discountStage3 = _discountStage3;
    discountStage4 = _discountStage4;
    discountStage5 = _discountStage5;
    token.setSaleAgent(owner);
  }

  // creates the token to be sold.
  function createTokenContract() internal returns (ZNAQToken) {
    return new ZNAQToken();
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary == address(0));
    require(validPurchase());

    if(now < startTime) {
        discountValue = discountStage1;
      } else if(now >= startTime + 7 days && now > startTime + 14 days) {
        discountValue = discountStage2;
      } else if(now >= startTime + 14 days && now < startTime + 21 days) {
        discountValue = discountStage3;
      } else if(now >= startTime + 21 days && now > startTime + 28 days) {
        discountValue = discountStage4;
      } else if(now >= startTime + 28 days) {
        discountValue = discountStage5;
      }

    uint256 weiAmount = msg.value;
    uint256 all = 100;
    uint256 tokens;
    // calculate token amount to be created
    if(discountValue != 0) {
      tokens = weiAmount.mul(rate).mul(100).div(all.sub(discountValue));
    }
    else {
      tokens = weiAmount.mul(rate).div(all.sub(discountValue));
    }

    // update state
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    forwardFunds();

    uint256 total = tokens.mul(100).div(60);
    uint256 mngTokens = total.mul(rate10).div(100);
    uint256 taaTokens = total.mul(rate15).div(100);
    uint256 companyTokens = total.mul(rate10).div(100);
    uint256 bountyTokens = total.mul(rate5).div(100);

    token.mint(MarketingNetworkGrowth, mngTokens);
    token.mint(TeamAndAdvisors, taaTokens);
    token.mint(Company, companyTokens);
    token.mint(Bounty, bountyTokens);

    TokenPartners(msg.sender, MarketingNetworkGrowth, mngTokens);
    TokenPartners(msg.sender, TeamAndAdvisors, taaTokens);
    TokenPartners(msg.sender, Company, companyTokens);
    TokenPartners(msg.sender, Bounty, bountyTokens);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  function discountInPercentage() public view returns (uint256 discount) {
      if(now > startTime) {
            return discountStage1;
      } else if(now >= startTime + 7 days && now < startTime + 14 days) {
            return discountStage2;
      } else if(now >= startTime + 14 days && now > startTime + 21 days) {
            return discountStage3;
      } else if(now >= startTime + 21 days && now < startTime + 28 days) {
            return discountStage4;
      } else if(now == startTime + 28 days) {
            return discountStage5;
      }
    }
    
  function setWallet(address _wallet) public onlyOwner {
    wallet = _wallet;
  }

  function setStartTime(uint256 _startTime) public onlyOwner {
    require(now < _startTime);
    startTime = _startTime;
  }
  function setEndTime(uint256 _endTime) public onlyOwner {
    endTime = _endTime;
  }

  function setTeamAddress(
    address _TeamAndAdvisors,
    address _Company,
    address _MarketingNetworkGrowth,
    address _Bounty) public onlyOwner {
    MarketingNetworkGrowth = _MarketingNetworkGrowth;
    TeamAndAdvisors = _TeamAndAdvisors;
    Company = _Company;
    Bounty = _Bounty;
  }

  function setDiscountStage1(uint256 _discountStage1) public onlyOwner {
    discountStage1 = _discountStage1;
  }
  function setDiscountStage2(uint256 _discountStage2) public onlyOwner {
    discountStage2 = _discountStage2;
  }
  function setDiscountStage3(uint256 _discountStage3) public onlyOwner {
    discountStage3 = _discountStage3;
  }
  function setDiscountStage4(uint256 _discountStage4) public onlyOwner {
    discountStage4 = _discountStage4;
  }
  function setDiscountStage5(uint256 _discountStage5) public onlyOwner {
    discountStage5 = _discountStage5;
  }

  function setRate(uint _newRate) public onlyOwner saleIsOn {
    rate = _newRate;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now < endTime;
  }
}
