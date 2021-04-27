import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';


export default class Contract {

    constructor(network, callback) {
        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));


        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.finishedInit = false;
    }

    balance(callback){

        this.web3.eth.getBalance((this.passengers[0]), (error, result) => {
          callback(error, this.web3.utils.fromWei(result,'ether'));
        });
    }

    credit(callback){
    this.flightSuretyApp.methods.creditAmount()
                        .call({ from: this.passengers[0]}, (error, result) => {
                            callback(error,  this.web3.utils.fromWei(result,'ether'));
                        
        });
    }

    initialize(callback)   {
        this.flightSuretyData.methods.authorizeCaller(this.flightSuretyApp._address).send({from: "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"});
        this.web3.eth.getAccounts((error, accts) => {
            this.owner = accts[0];
            
            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
        
    }

    buyTicket( flight , insured, passenger, callback) {
        let self = this;
        let payload = {
            airline: flight.airline,
            flight: flight.flightNumber,
            timestamp: Math.floor(flight.timestamp / 1000),
            
            price: self.web3.utils.toWei((flight.price + 1).toString())
        } 
      
        self.flightSuretyApp.methods
            .buyTicket(payload.flight ,payload.timestamp, payload.airline,insured)
            .send({ from: passenger,value:payload.price}, (error, result) => {
                callback(error, payload);
                
            });
    }
    

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods.isOperational().call({from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: flight.airline,
            flight: flight.flightNumber,
            timestamp: Math.floor(flight.timestamp / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
                
            });
    }

        getFlightStatus(flight,callback){
            let self = this;
            let payload = {
                airline: flight.airline,
                flight: flight.flightNumber,
                timestamp: Math.floor(flight.timestamp / 1000)
            } 
            self.flightSuretyApp.methods
                .getFlightStatus( payload.flight ,payload.timestamp, payload.airline)
                .call({ from: self.owner}, (error, result) => {
                    callback(error, result);
                    
                });
        }
        payInsuree(flight,passenger,callback){
            let self = this;
            let payload = {
                airline: flight.airline,
                flight: flight.flight,
                timestamp: flight.timestamp
            } 
            self.flightSuretyApp.methods
                .getCredit( payload.flight ,payload.timestamp, payload.airline)
                .send({ from: passenger}, (error, result) => {
                    if (error != null){
                        callback(error,result);
                    }
                });
        }

        redeemCredit(passenger,callback){
            let self = this;
            self.flightSuretyApp.methods.receiveCredit()
            .send({ from: passenger}, (error, result) => {
                    callback(error,result);
            });
    }

        
}
