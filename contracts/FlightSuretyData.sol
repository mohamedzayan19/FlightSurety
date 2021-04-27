pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

/*****************Contact Variables*******************/
/**                                                  */
/*****************************************************/
    address private contractOwner;
    bool private operational = true;
    uint256 public registeredCount = 0;

    uint256 public constant AirlineRegistrationFee = 10 ether;

    struct airliner {
      bool registered;
      bool hasPaid;
      mapping(address => bool) voters;
      uint256 votes;
    }

    struct clientFlights {
      bool exist;
      uint256 status;
      bool registered;
      uint256 departuretime;
      uint256 price;
      mapping(address => bool) didByInsurance;
    }

    mapping(address => uint256) private credit;
    mapping(address => bool) private authorizeCallers;
    mapping(bytes32 => clientFlights) private flights;

    mapping(address => airliner) private registerQue;
/*****************************************************/

/****************Contract Constructor*****************/
/**                                                  */
/*****************************************************/
  constructor() public
    {
        contractOwner = msg.sender;
        airliner memory NewAirline;
        NewAirline.registered = true;
        NewAirline.hasPaid = true;
        NewAirline.votes = 0;
        registerQue[msg.sender] = NewAirline;
        registeredCount = registeredCount.add(1);
    }

/*****************************************************/

/**************Contract Modifiers*********************/
/**                                                  */
/*****************************************************/
    modifier isAuthorized()
    {
      require(authorizeCallers[msg.sender] == true, "Address is not authorized to make calles on data contract");
      _;
    }

    modifier requireIsOperational()
    {
        require(operational == true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier wasInsuranced(bytes32 key, address _address)
    {
      require(flights[key].didByInsurance[_address] == true, "Address is not insuranced or was  already refunded for this flight");
      _;
    }

    modifier isNotInsuranced(bytes32 key, address _address)
    {
      require(flights[key].didByInsurance[_address] == false, "Address already has insurance for this flight");
      _;
    }

    modifier flightExists(bytes32 key)
    {
      require(flights[key].exist == true, "Flight Doesn't exist");
      _;
    }

    modifier flightstatus(bytes32 key)
    {
      require(flights[key].status != 10, "Flight was on time no insurance for you");
      _;
    }

    modifier timesUp(bytes32 key)
    {
      require(flights[key].departuretime >= now, "Too late to buy insurance for this flight");
      _;
    }

    modifier toSoon(bytes32 key)
    {
      require(flights[key].departuretime < now, "Flight must be passed depature data for insurance payout");
      _;
    }

    modifier minimumFundBalance()
    {
      require(address(this).balance > 10 ether, "Contract has insufficient funds for withdraw");
      _;
    }
    modifier checkBalance(address _address)
    {
      require(credit[_address] > 0, "Address has no credit");
      _;
    }

/*****************************************************/

/****************Contract Functions*******************/
/**                                                  */
/*****************************************************/
    function hasPaid(address _address) external view
    requireIsOperational()
    isAuthorized()
    returns(bool)
    {
    return (registerQue[_address].hasPaid);
    }

    function changeOperation() external
    requireContractOwner()
    {
      if(operational == true){
        operational = false;
      }else{
        operational = true;
      }
    }

    function isOperational() external view
    isAuthorized()
    returns(bool)
    {
      return (operational);
    }

    function authorizeCaller(address addressToAuthorize) external
    requireContractOwner()
    {
      authorizeCallers[addressToAuthorize] = true;
    }


    function hasAlreadyVoted(address addressToPromote, address promoter) external view
    requireIsOperational()
    isAuthorized()
    returns(bool)
      {
        return (registerQue[addressToPromote].voters[promoter]);
      }

    function getRegistrationCount() external view
    requireIsOperational()
    isAuthorized()
    returns(uint256)
      {
        return (registeredCount);
      }

    function isRegisterAirline(address addressToCheck) external view
    requireIsOperational()
    isAuthorized()
    returns(bool registered, bool paid ,uint256 votes)
      {
        airliner memory addressFetched = registerQue[addressToCheck];
        return (addressFetched.registered,addressFetched.hasPaid,addressFetched.votes);
      }
    function isInsured(bytes32 key, address _address) external view returns(bool)
    {
      return (flights[key].didByInsurance[_address]);
    }

    function getTicketPriceWithInsurance(bytes32 key) external view
    requireIsOperational()
    isAuthorized()
    flightExists(key)
    returns(uint256 ticketPrice, uint256 ticketPriceWithInsurance)
    {
      uint256 priceWithInsurance = flights[key].price.add(AirlineRegistrationFee);
      return (flights[key].price,priceWithInsurance);
    }

    function getFlight(bytes32 key) external view
    isAuthorized()
    returns(bool exist,uint256 status,bool registered,uint256 departuretime,uint256 price)
    {
      return (flights[key].exist,flights[key].status,flights[key].registered,flights[key].departuretime,flights[key].price);
    }

    function updateFlightStatus(bytes32 key, uint256 status) external
    requireIsOperational()
    isAuthorized()
    flightExists(key)
    {
      flights[key].status = status;
    }

    function getCurrentConsieses() external view
    requireIsOperational()
    isAuthorized()
    returns(uint256)
      {
        uint256 consieses = registeredCount.div(2);
        return (consieses);
      }

    function changeRegisteration(address addressToRegister,bool registrationState) external
    requireIsOperational()
    isAuthorized()
      {
        registerQue[addressToRegister].registered = registrationState;
        registeredCount = registeredCount.add(1);
      }

    function addVote(address addressToPromote, address promoter) external
    requireIsOperational()
    isAuthorized()
      {
        registerQue[addressToPromote].voters[promoter] = true;
        registerQue[addressToPromote].votes = registerQue[addressToPromote].votes.add(1);
      }

    function payFee(address addressThatPaid) external payable
    requireIsOperational()
      isAuthorized()
      {
        registerQue[addressThatPaid].hasPaid = true;
      }

    function addRegisteredFlight(bytes32 key, uint256 price, uint256 time) external
    requireIsOperational()
    isAuthorized()
      {
        clientFlights memory registeredFlight;
        registeredFlight.exist = true;
        registeredFlight.status = 10;
        registeredFlight.registered = true;
        registeredFlight.price = price;
        registeredFlight.departuretime = time;
        flights[key] = registeredFlight;
      }


    function buy(bytes32 key, address buyer, bool withInsurance) external payable
    requireIsOperational()
    isAuthorized()
    isNotInsuranced(key, buyer)
    flightExists(key)
    timesUp(key)
      {
        if(withInsurance == true){
          flights[key].didByInsurance[buyer] = true;
        }
      }

    function creditInsurees(address _address) external view
    requireIsOperational()
    isAuthorized()
    returns (uint256)
      {
        return (credit[_address]);
      }

    function pay(address _address) external
    requireIsOperational()
    isAuthorized()
    checkBalance(_address)
    minimumFundBalance()
      {
       _address.transfer(credit[_address]);
       credit[_address] = 0;
      }

    function fund(bytes32 key,address _address) public
    requireIsOperational()
    isAuthorized()
    toSoon(key)
    wasInsuranced(key,_address)
    flightstatus(key)
      {
        flights[key].didByInsurance[_address] = false;
        uint256 half = flights[key].price.div(2);
        uint256 amountTofund = flights[key].price.add(half);
        credit[_address] += amountTofund;
      }

    function getFlightKey(address airline,string memory flight,uint256 timestamp) internal pure returns(bytes32)
      {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
      }

    function() external payable
    {
      //fund();
    }
/*****************************************************/

}
