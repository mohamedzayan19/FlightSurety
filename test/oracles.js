
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;

  });


  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle ${accounts[a]} Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can submit oracle response flight status', async () => {
    let contractowner = accounts[0];
    // ARRANGE
    let flight = 'ND1309'; // Course number
    const timestamp = Math.floor(Date.now() / 1000);

    // Submit a request for oracles to get status information for a flight
    console.log("Calling fetchFlightStatus ")
    console.log(timestamp);

    await config.flightSuretyApp.registerFlight(flight,timestamp,200,{from:contractowner});

    await config.flightSuretyApp.fetchFlightStatus(contractowner, flight, timestamp);
    // ACT
    console.log(`Airliner: ${contractowner}, Flight: ${flight}, Timestamp:${timestamp}`);

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    let addressIndexes = [];
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {
      // Get oracle information
      let setThree = [];
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for (let b=0; b<=oracleIndexes.length;b++){
        let number = oracleIndexes[b];
        setThree.push(number);
      }
      addressIndexes.push(setThree);
      for(let idx=0;idx<3;idx++) {
        try {
          // Submit a response...it will only be accepted if there is an Index match
          console.log(`Airliner: ${config.firstAirline}, Flight: ${flight}, Timestamp:${timestamp}`);
        }
        catch(e) {
          // Enable this when debugging
           console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }
      }
    }

    //config.flightSuretyApp.getPastEvents("allEvents", {fromBlock: 0, toBlock: "latest"})
    //.then(console.log)  

    await config.flightSuretyApp.getPastEvents('allEvents', {
      fromBlock: 0,
      toBlock: 'latest'
  }, (error, events) => { console.log(events,error); })
    .then( async (events) => {
        let indexTorespond = events[0].args.index
        for(let a=0;a< addressIndexes.length;a++){
          for(let b=0;b< 3;b++){
            if(addressIndexes[a][b].toNumber() == indexTorespond.toNumber()){
              await config.flightSuretyApp.submitOracleResponse(addressIndexes[a][b],contractowner , flight, timestamp, 10, { from: accounts[a +1] });
            };
          };
        };
      });

    
      sleep(5000)
      let result = await config.flightSuretyApp.getFlightStatus.call(flight,timestamp,contractowner);
      console.log(result.status.toString());  
    });  


});
