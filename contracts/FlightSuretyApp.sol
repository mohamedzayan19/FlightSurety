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

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    FlightSuretyData flightSuretyData;
    address private contractOwner;          // Account used to deploy contract
    uint256 no_airlines = 1;
    uint256 M = 1;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    address [] multiCallers = new address[](0);
 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isActiveAirline(address airlineAddress)
    {
        require(flightSuretyData.isActiveAirline(airlineAddress)== true, "Can only be registered by an active airline");
        _;
    }

    modifier existsAirline(address airlineAddress)
    {
        require(flightSuretyData.existsAirline(airlineAddress)== true, "Airline already registered");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);

        flightSuretyData.registerAirline("Egypt Air", true,address(0x627306090abaB3A6e1400e9345bC60c78a8BEf57));
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address airline,
                                string name   
                            )
                            external
                            existsAirline(airline)
                            isActiveAirline(msg.sender)
                            returns(bool success, uint256 votes)
                                    
    {
        votes = 0;
        success = false;
        if(no_airlines<4){
            flightSuretyData.registerAirline(name,false, airline);
            no_airlines++;
            success = true;
        }else{
            bool isDuplicate = false;
            for (uint256 c = 0; c<multiCallers.length;c++){
                if(multiCallers[c]==msg.sender){
                    isDuplicate = true;
                    break;
                }
            }
            require(isDuplicate==false, "Airline already voted");
            multiCallers.push(msg.sender);
            votes = multiCallers.length;
            if(multiCallers.length>=M){
                flightSuretyData.registerAirline(name, false, msg.sender);
                no_airlines++;
                success = true;
                multiCallers = new address[](0);
            }
        }

        M = no_airlines/2;
        return (success, votes);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    //bool isRegistered;
                                    //uint8 statusCode;
                                    string flightName,
                                    uint256 updatedTimestamp,        
                                    address airline
                                )
                                external
                                isActiveAirline(msg.sender)
    {
        require(msg.sender == airline, "You can only register your own flights");
        Flight memory flight = Flight(true, 10, updatedTimestamp, airline);
        bytes32 key = getFlightKey(airline, flightName, updatedTimestamp);
        flights[key] = flight;
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flights[key].statusCode = statusCode;
        if(statusCode==20){
            flightSuretyData.creditInsurees(key);
        }
    }

    function getFlightStatus(string flight ,uint256 _timestamp, address airline) external
      requireIsOperational()
      returns(bool registered, uint256 status,uint256 departuretime, bytes32 _key)
      {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        return (flights[key].isRegistered, flights[key].statusCode, flights[key].updatedTimestamp ,key) ;
      }
    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        returns (bytes32)
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
        return key;
    } 


// region ORACLE MANAGEMENT

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
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
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
    function generateIndexes
                            (                       
                                address account         
                            )
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
    function getRandomIndex
                            (
                                address account
                            )
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

// endregion
    function buy
                            (
                                string flight ,
                                uint256 _timestamp, 
                                address airline
                            )
                            external
                            payable
    {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        //address(flightSuretyData).transfer(2);
        flightSuretyData.buy(key,msg.sender,msg.value);
    }

    function creditAmount   (
                                address buyer
                            ) 
    external 
      requireIsOperational()
      returns (uint256)
      {
        return(flightSuretyData.getAmounts(buyer));
      }

         /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (
                            )
                            public
                            payable
    {
        require(msg.value>=10, "Minimum requirement is 10 ether");
        //address receiver = address(flightSuretyData);
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.fund(msg.sender);
    }
    function isRegistered
                            (
                                address _address
                            )
                            public
                            returns (bool)
    {
        return flightSuretyData.isRegistered(_address);
    }

    function getPassengers
                            (
                                string flight,
                                uint256 _timestamp,
                                address airline
                            )
                            public
                            returns (uint256)
    {
        bytes32 key = getFlightKey(airline, flight, _timestamp);
        return flightSuretyData.getPassengers(key);
    }

    function payInsuree 
                        (
                            address _address
                        )
                        public
    {
        //_address.transfer(200000);
        flightSuretyData.payInsuree(_address);
    }

}   

contract FlightSuretyData {
    function registerAirline(string name, bool activated, address _addr) external;
    function isActiveAirline(address airlineAddress) external returns(bool);
    function existsAirline(address airlineAddress) external returns(bool);
    function creditInsurees(bytes32 key) external;
    function buy(bytes32 flight, address buyer, uint256 amount) external;
    function getAmounts(address _address) external returns (uint256);
    function fund(address) external;
    function isRegistered(address) external returns (bool);
    function getPassengers(bytes32 key) external returns (uint256);
    function payInsuree(address) public;
}