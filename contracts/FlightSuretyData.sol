pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct Airline {
        string name;
        bool activated;
        bool exists;
    }

    mapping(address => Airline) airlines;

    mapping(address => uint256) balances;

    mapping(address => mapping(bytes32 => uint256)) investmentsPerFlight;

    mapping(bytes32 => address[]) flightPassengers;

    address authorizedContract = address(0);

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is currently not operational");
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

    modifier requireAuthorizedContract()
    {
        require(msg.sender == authorizedContract, "Caller contract is not authorized");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function isActiveAirline(address airlineAddress) external returns(bool)
    {
        return(airlines[airlineAddress].activated);

    }

    function existsAirline(address airlineAddress) external returns(bool)
    {
        return(airlines[airlineAddress].exists==false);

    }

    function authorizeCaller(address appContract) external
    {
        authorizedContract = appContract;

    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                string name,
                                bool activated ,
                                address _addr
                            )
                            external
    {
        Airline memory airline = Airline(name, activated, true);
        airlines[_addr] = airline; 
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                bytes32 flight,
                                address buyer,
                                uint256 amount                            
                            )
                            external
                            payable
    {
       // require(amount+investmentsPerFlight[buyer][flight]<=1, "Cannot invest more tha one ether");

        investmentsPerFlight[buyer][flight] += amount;

        flightPassengers[flight].push(buyer);

        //balances[buyer] += amount;

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 key
                                )
                                external
    {
        address [] memory passengers = flightPassengers[key];
        for(uint256 c = 0; c<passengers.length;c++){
            address passenger = passengers[c];
            uint256 flightInvestment = investmentsPerFlight[passenger][key];
            uint256 value = flightInvestment.mul(3)-flightInvestment;
            balances[passenger] = balances[passenger] + value;
        } 
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
    {
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(balance);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (
                                address _addr
                            )
                            public
                            payable
    {
        airlines[address(_addr)].activated=true;
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        //fund(msg.sender);
    }


    function getAmounts(address _address) external view
    requireIsOperational()
    returns (uint256)
      {
        return (balances[_address]);
      }
    function isRegistered
                            (
                                address _address
                            )
                            public
                            returns (bool)
    {
        return airlines[_address].exists;
    }

   function getPassengers
                            (
                                bytes32 key
                            )
                            public
                            returns (uint256)
    {
        return flightPassengers[key].length;
    }

    function payInsuree 
                        (
                            address _address
                        )
                        public
    {
        require(balances[_address]>0, "Not enough balance");
        uint256 balance = balances[_address];
        balances[_address] = 0;
        _address.transfer(balance);
    }
}

