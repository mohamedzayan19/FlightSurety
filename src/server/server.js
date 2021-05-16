import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import { Random } from "random-js";
import "babel-polyfill";

const random = new Random();
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flights_airlines = [];
var orcales = [];
let timestamp = (new Date).getTime();

(async() => {
	let accounts = await web3.eth.getAccounts();
	let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
	let OracleAccounts = accounts.splice(30, 30);

	let airlines = [accounts[0], accounts[1]];
	let airline_name = ["Egypt Air", "Lufthansa"]
	console.log(accounts[0]);

	for(let b = 1; b < airlines.length; b++){
    try{
        //await flightSuretyApp.methods.promoteAddressFromRegistration(airlines[b]).send({from:firstAirline});
        //let regFee = await flightSuretyApp.methods.AirlineRegistrationFee().call();
        //await flightSuretyApp.methods.payRegistrationFee().send({from:airlines[b]});
        let fee = web3.utils.toWei('11', 'ether')
        await flightSuretyApp.methods.registerAirline(airlines[b],airline_name[b]).send({from:airlines[0], gas:3000000});
        await flightSuretyApp.methods.fund().send({from:airlines[b], value:fee, gas:3000000});
        let isReg = await flightSuretyApp.methods.isRegisterAirline(airlines[b]).call();
        console.log(isReg);
    }catch(error){
      console.log(error);
    }
  }
	//console.log(OracleAccounts);
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
      //console.log("done");
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
    if (error) {console.log(error);}else{
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

app.get('/api/fetchFlights', async(req, res) => {
	//flights_airlines[i].timestamp = timestamp;
	let timestamp = (new Date).getTime()+ random.integer(20000,500000);
	let accounts = await web3.eth.getAccounts();
	//timestamp = Math.floor(timestamp / 1000);
	//console.log(accounts);
	flights_airlines = [{'airline':accounts[0], 'flight':'MS 785','timestamp':timestamp}, {'airline':accounts[0], 'flight':'MS 786','timestamp':timestamp}
	,{'airline':accounts[1], 'flight':'LH 541','timestamp':timestamp}];
	//egyptAirAddress = accounts[0];
	for(let i = 0;i<flights_airlines.length;i++){
		try{
		const estimateGas = await flightSuretyApp.methods.registerFlight(flights_airlines[i].flight, timestamp, flights_airlines[i].airline).estimateGas({from:flights_airlines[i].airline});
		await flightSuretyApp.methods.registerFlight(flights_airlines[i].flight, timestamp, flights_airlines[i].airline).send({from:flights_airlines[i].airline, gas:3000000000});
		console.log(flights_airlines[i].airline);
		let result = await flightSuretyApp.methods.getFlightStatus(flights_airlines[i].flight, timestamp, flights_airlines[i].airline).call();
		console.log(result);
		}catch(error){
      console.log(error);
    }
	}

        // do some processing of result into finalData
        res.status(200).send(flights_airlines);
	
	
})	

export default app;