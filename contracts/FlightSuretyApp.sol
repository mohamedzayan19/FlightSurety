pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData flightSuretyData;

  /*******************Contact Variables***********************/
  /**                                                        */
  /***********************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;

    uint256 public constant AirlineRegistrationFee = 10 ether;
    uint256 public constant Insurance_FEE = 1 ether;

        constructor(address dataContract) public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

  /***********************************************************/

    /******************** Modifiers***********************/
    /**                                                  */
    /*****************************************************/
      modifier requireIsOperational()
      {
          // Modify to call data contract's status
          bool status = flightSuretyData.isOperational();
          require(status == true, "Contract is currently not operational");
          _;  // All modifiers require an "_" which indicates where the function body will be added
      }

      modifier requireContractOwner()
      {
          require(msg.sender == contractOwner, "Caller is not contract owner");
          _;
      }

      modifier requireRegisteredUser(address addressToCheck)
      {
        // check if address is in registerQue mapping
        (bool registered, bool haspaid, uint256 votes) = flightSuretyData.isRegisterAirline(addressToCheck);
        require(registered == true, "Sender is not registered");
        require(haspaid == true,"Sender has not paid registration fee");
        _;
      }

      // Define a modifier that checks if the paid amount is sufficient to cover the price
      modifier paidEnough(uint _price)
      {
        require(msg.value >= _price, "Pay Some more");
        _;
      }

      // Define a modifier that checks the price and refunds the remaining balance
      modifier checkValue(uint _price, address addressToFund)
      {
        uint  amountToReturn = msg.value - _price;
        addressToFund.transfer(amountToReturn);
        _;
      }

      modifier checkVoter(address _address, address _promoter)
      {
        bool hasVoted = flightSuretyData.hasAlreadyVoted(_address, _promoter);
        require(hasVoted == false, "Voters has already promoted address");
        _;
      }

    /*****************************************************/


    /*********************Tool functions******************/
    /**                                                  */
    /*****************************************************/
      function isOperational() external returns (bool)
      {
        return flightSuretyData.isOperational();
      }

      function getRegistrationCount() external
      requireIsOperational()
      returns(uint256)
      {
        return flightSuretyData.getRegistrationCount();
      }

      function getCurrentConsieses() external
      requireIsOperational()
      returns(uint256)
      {
        return flightSuretyData.getCurrentConsieses();
      }

      function isRegisterAirline(address addressToCheck) external
      requireIsOperational()
      returns(bool registered,bool hasPaid, uint256 votes)
      {
          return flightSuretyData.isRegisterAirline(addressToCheck);
      }

      function contractTime() external view
      returns(uint256)
      {
        return (now);
      }

      function getFlightStatus(string flight ,uint256 _timestamp, address airline) external
      requireIsOperational()
      returns(bool exist,uint256 status,bool registered,uint256 departuretime,uint256 price)
      {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        return (flightSuretyData.getFlight(key));
      }
    /*****************************************************/



    /******************Airline Functions*******************/
    /**                                                   */
    /******************************************************/

        function promoteAddressFromRegistration(address addressToPromote) external
          requireIsOperational()
          checkVoter(addressToPromote, msg.sender)
          requireRegisteredUser(msg.sender)
          {
            if (flightSuretyData.getRegistrationCount() <= 4){
              flightSuretyData.changeRegisteration(addressToPromote,true);
            }else{ 
              flightSuretyData.addVote(addressToPromote,msg.sender);
              uint256 consieses = flightSuretyData.getCurrentConsieses();
              (bool registered, bool haspaid, uint256 votes) = flightSuretyData.isRegisterAirline(addressToPromote);
              if (consieses <= votes && registered == false){
                flightSuretyData.changeRegisteration(addressToPromote,true);
                }
              }
          }



      function payRegistrationFee() external payable
        requireIsOperational()
        paidEnough(AirlineRegistrationFee)
        checkValue(AirlineRegistrationFee,msg.sender)
        {
          require(flightSuretyData.hasPaid(msg.sender) == false, "Sender has already paid airline fee");
          address(flightSuretyData).transfer(msg.value);
          flightSuretyData.payFee(msg.sender);
        }


      function registerFlight(string _flight, uint256 _timestamp, uint256 _price) external
        requireIsOperational()
        requireRegisteredUser(msg.sender)
        {
          bytes32 key = getFlightKey(msg.sender, _flight,_timestamp);
          flightSuretyData.addRegisteredFlight(key,_price,_timestamp);
        }

    /******************************************************/


    /******************Insurance Functions*****************/
    /**                                                   */
    /******************************************************/
        function getTicketPrice(string flight ,uint256 _timestamp, address airline) external 
        requireIsOperational()
        returns(uint256,uint256)
      {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        return flightSuretyData.getTicketPriceWithInsurance(key);
      }

      function buyTicket(string flight ,uint256 _timestamp, address airline,bool insured) external payable
      requireIsOperational()
      {

        uint256  amountToReturn;
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        (uint256 ticketPriceWithout ,uint256 ticketPriceWith) = flightSuretyData.getTicketPriceWithInsurance(key);

        if (insured == true){
          require (msg.value >= ticketPriceWith, "Need more Ether for ticket with insurance");
          amountToReturn = msg.value.sub(ticketPriceWith);
          msg.sender.transfer(amountToReturn);
          address(flightSuretyData).transfer(ticketPriceWith);
          flightSuretyData.buy(key,msg.sender,insured);

        }else{
          require (msg.value >= ticketPriceWithout, "Need more Ether for ticket");
          amountToReturn = msg.value.sub(ticketPriceWithout);
          msg.sender.transfer(amountToReturn);
          address(flightSuretyData).transfer(ticketPriceWithout);
          flightSuretyData.buy(key,msg.sender,insured);
        }
      }

      function receiveCredit() external
      requireIsOperational()
      {
        flightSuretyData.pay(msg.sender);
      }

      function isInsured(string flight ,uint256 _timestamp, address airline) external 
      requireIsOperational()
      returns(bool)
      {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        return flightSuretyData.isInsured(key,msg.sender);
      }

      function getCredit(string flight ,uint256 _timestamp, address airline) external
      requireIsOperational()
      {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        flightSuretyData.fund( key,msg.sender);
      }

      function creditAmount() external 
      requireIsOperational()
      returns (uint256)
      {
        return(flightSuretyData.creditInsurees(msg.sender));
      }



    /******************************************************/
 
    /********************Oracle Functions******************/
    /**                                                   */
    /******************************************************/

      function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) internal
      
      {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flightSuretyData.updateFlightStatus(key, statusCode);
      }


      function fetchFlightStatus(address airline, string flight,uint256 timestamp) external
      requireIsOperational()
      {
          uint8 index = getRandomIndex(msg.sender);

          // Generate a unique key for storing the request
          bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
          oracleResponses[key] = ResponseInfo({
                                                  requester: msg.sender,
                                                  isOpen: true
                                              });

          emit OracleRequest(index, airline, flight, timestamp);
      } 

      // Incremented to add pseudo-randomness at various points
      uint8 private nonce = 0;    

      // Fee to be paid when registering oracle
      uint256 public constant REGISTRATION_FEE = 1 ether;

      // Number of oracles that must respond for valid status
      uint256 private constant MIN_RESPONSES = 3;


      struct Oracle {
          bool isRegistered;
          uint8[3] indexes;        
      }

      // Track all registered oracles
      mapping(address => Oracle) private oracles;

      // Model for responses from oracles
      struct ResponseInfo {
          address requester;                              // Account that requested status
          bool isOpen;                                    // If open, oracle responses are accepted
          mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                          // This lets us group responses and identify
                                                          // the response that majority of the oracles
      }

      // Track all oracle responses
      // Key = hash(index, flight, timestamp)
      mapping(bytes32 => ResponseInfo) private oracleResponses;

      // Event fired each time an oracle submits a response
      event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

      event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

      // Event fired when flight status request is submitted
      // Oracles track this and if they have a matching index
      // they fetch data and submit a response
      event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


      // Register an oracle with the contract
      function registerOracle() external payable
      requireIsOperational()
      {
          //Require registration fee
          require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

          uint8[3] memory indexes = generateIndexes(msg.sender);

          oracles[msg.sender] = Oracle({
                                          isRegistered: true,
                                          indexes: indexes
                                      });
      }

      function getMyIndexes() external
      requireIsOperational()
      returns(uint8[3])
      {
          require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

          return oracles[msg.sender].indexes;
      }

      // Called by oracle when a response is available to an outstanding request
      // For the response to be accepted, there must be a pending request that is open
      // and matches one of the three Indexes randomly assigned to the oracle at the
      // time of registration (i.e. uninvited oracles are not welcome)
      function submitOracleResponse(uint8 index, address airline,string flight,uint256 timestamp,uint8 statusCode) external
      requireIsOperational()
      {
          require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


          bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
          require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

          oracleResponses[key].responses[statusCode].push(msg.sender);

          // Information isn't considered verified until at least MIN_RESPONSES
          // oracles respond with the *** same *** information
          emit OracleReport(airline, flight, timestamp, statusCode);
          if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

              emit FlightStatusInfo(airline, flight, timestamp, statusCode);

              // Handle flight status as appropriate
              processFlightStatus(airline, flight, timestamp, statusCode);
          }
      }


      function getFlightKey
                          (
                              address airline,
                              string flight,
                              uint256 timestamp
                          )
                          pure
                          internal
                          
                          returns(bytes32) 
      {
          return keccak256(abi.encodePacked(airline, flight, timestamp));
      }

      // Returns array of three non-duplicating integers from 0-9
      function generateIndexes(address account)
                              internal
                              returns(uint8[3])
      {
          uint8[3] memory indexes;
          indexes[0] = getRandomIndex(account);
          
          indexes[1] = indexes[0];
          while(indexes[1] == indexes[0]) {
              indexes[1] = getRandomIndex(account);
          }

          indexes[2] = indexes[1];
          while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
              indexes[2] = getRandomIndex(account);
          }

          return indexes;
      }

      // Returns array of three non-duplicating integers from 0-9
      function getRandomIndex(address account)
      internal
      returns (uint8)
      {
          uint8 maxValue = 10;

          // Pseudo random number...the incrementing nonce adds variation
          uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

          if (nonce > 250) {
              nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
          }

          return random;
      }

    /******************************************************/
}

/*********************DataContact Functions***********************/
/**                                                       */
/**********************************************************/
  contract FlightSuretyData {
    function getRegistrationCount() external returns(uint256);
    function isRegisterAirline(address addressToCheck) external returns(bool registered,bool hasPaid, uint256 votes);
    function changeRegisteration(address addressToRegister, bool registrationState) external;
    function addVote(address addressToPromote, address _promoter) external;
    function getCurrentConsieses() external returns(uint256);
    function payFee(address addressThatPaid) external payable;
    function hasAlreadyVoted(address addressToPromote, address promoter) external returns(bool);
    function addRegisteredFlight(bytes32 key,uint256 price, uint256 time) external;
    function buy(bytes32 key,address buyer, bool withInsurance) external payable;
    function pay(address _address) external;
    function isInsured(bytes32 key, address _address) external returns(bool);
    function getTicketPriceWithInsurance(bytes32 key) external returns(uint256 ticketPrice, uint256 ticketPriceWithInsurance);
    function fund(bytes32 key , address _address) public;
    function creditInsurees(address _address) external returns (uint256);
    function updateFlightStatus(bytes32 key, uint256 status) external;
    function getFlight(bytes32 key) external returns(bool exist,uint256 status,bool registered,uint256 departuretime,uint256 price);
    function isOperational() external returns(bool);
    function hasPaid(address _address) external returns(bool);
  }
/**********************************************************/
