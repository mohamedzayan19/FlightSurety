import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import { Random } from "random-js";
import { resolve } from 'path';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let firstAirline;
let airlines;
var orcales = [];
let allFlight = [];
const random = new Random();
let flights = ["GHE145","SJA128","JYH098","QJD192","ALO182","QUI871","YET176","JKD987","IET108"];


class flight {
  constructor(flightNumber,airline){
    this.flightNumber = flightNumber;
    this.airline = airline;
    this.timestamp = (new Date).getTime() + random.integer(20000,1000000);
    this.price = web3.utils.toWei(random.integer(2,30).toString());
    
  }
}

(async() => {
  await flightSuretyData.methods.authorizeCaller(flightSuretyApp._address).send({from: "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"});
  let accounts = await web3.eth.getAccounts();
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  let OracleAccounts = accounts.splice(30, 30);
  airlines = accounts.splice(2,3);
  
  firstAirline = accounts[0];
  for(let b = 0; b < airlines.length; b++){
    try{
        await flightSuretyApp.methods.promoteAddressFromRegistration(airlines[b]).send({from:firstAirline});
        let regFee = await flightSuretyApp.methods.AirlineRegistrationFee().call();
        await flightSuretyApp.methods.payRegistrationFee().send({from:airlines[b], value:regFee});
        let isReg = await flightSuretyApp.methods.isRegisterAirline(airlines[b]).call();
        //console.log(isReg);
    }catch(error){
      //console.log(error);
    }
  }

  // register orcales

  for(let c =0; c < OracleAccounts.length; c++){
    try{
      const estimateGas = await flightSuretyApp.methods.registerOracle().estimateGas({from: OracleAccounts[c], value: fee});
      await flightSuretyApp.methods.registerOracle().send({from: OracleAccounts[c], value:fee, gas:estimateGas});
      let index = await flightSuretyApp.methods.getMyIndexes().call({from: OracleAccounts[c]});
      orcales.push({
        address : OracleAccounts[c],
        indexes : index
      })
    }catch(error){
      console.log(error);
    }
  }
})();


console.log("Registering Orcales && Airlines...");

(function() {
  var P = ["\\", "|", "/", "-"];
  var x = 0;
  return setInterval(function() {
    process.stdout.write("\r" + P[x++]);
    x &= 3;
  }, 250);
})();

setTimeout(() => {
  orcales.forEach(orcale => {
    console.log(`Oracle Address: ${orcale.address}, has indexes: ${orcale.indexes}`);
  })
  console.log("\nStart watching for event OracleRequest to submit responses")
}, 25000)


 function randomFlightStatus(){
  const random = new Random(); // uses the nativeMath engine
   return (Math.ceil((random.integer(1, 50)) / 10) * 10);
 }


flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
  if (error) {
    console.log(error)
  }else {
    console.log(event)
    
    let randomStatusCode = randomFlightStatus();
    let eventValue = event.returnValues;
    console.log(`Got a new event with randome index: ${eventValue.index} for flight: ${eventValue.flight} and timestamp ${eventValue.timestamp}`);

    orcales.forEach((oracle) => {
      oracle.indexes.forEach((index) => {
        flightSuretyApp.methods.submitOracleResponse(
          index, 
          eventValue.airline, 
          eventValue.flight, 
          eventValue.timestamp, 
          randomStatusCode
          ).send(
          { from: oracle.address , gas:5555555}
          ).then(res => {
            console.log(`--> Report from oracles(${oracle.address}).index(${index}) accepted with status code ${randomStatusCode}`)
          }).catch(err => {
            console.log(`--> Report from oracles(${oracle.address}).index(${index}) rejected with status code ${randomStatusCode}`)
          });
        });
    });
  }
});

// 10 flight registered and price by the airline are shown to the user in the dapp
// user can buy a flight with / without incurace 
// when flight depart time is true, user can look up flight status
// if flight is delayed user can withdraw 1.5 the amount paid


const app = express();

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

app.get('/api/fetchFlights', (req, res) => {
    while(allFlight.length > 0) {
      allFlight.pop();
    }
    
    for(let a = 0; a < flights.length; a ++){ 
      const random = new Random();
      let newAirline = airlines[random.integer(0, airlines.length -1 )];
      let newFlight = new flight(flights[a],newAirline);
      let timestamp = Math.floor(newFlight.timestamp / 1000)
      allFlight.push(newFlight);
      (async() => {
        try{
          const estimateGas = await flightSuretyApp.methods.registerFlight(newFlight.flightNumber, timestamp,newFlight.price).estimateGas({from: newFlight.airline});
            //console.log(newFlight.flightNumber,newFlight.timestamp,newFlight.price,newFlight.airline)
            await flightSuretyApp.methods.registerFlight(newFlight.flightNumber, timestamp,newFlight.price).send({from: newFlight.airline, gas:estimateGas});
            //let result = await flightSuretyApp.methods.getFlightStatus(newFlight.flightNumber,timestamp,newFlight.airline).call();
            //console.log(result);
        }catch(error){
          console.log(error);
        }
      })();
    }
    res.status(200).send(allFlight);
})





export default app;