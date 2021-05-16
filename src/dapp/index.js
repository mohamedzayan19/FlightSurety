
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

let flights;
let contract;

(async() => {

    let result = null;
    contract = new Contract('localhost', () => {

        var xmlHttp = new XMLHttpRequest();
        xmlHttp.open( "GET", "http://127.0.0.1:3000/api/fetchFlights", false ); // false for synchronous request
        xmlHttp.send( null );
        console.log('hi');
        var jsonResponse = JSON.parse(xmlHttp.responseText);
        flights = jsonResponse;
        let main = DOM.elid("flightInfoTable");
        console.log(flights);

            for(let a = 0; a < jsonResponse.length;a++){
            //jsonResponse[a].price = contract.web3.utils.fromWei(jsonResponse[a].price,'ether');
            let newRow = document.createElement("tr");
            let flightnumber = document.createElement("td");
            let airline = document.createElement("td");
            let price = document.createElement("td");
            let depart = document.createElement("td");
            let status = document.createElement("td");
            let select = document.createElement("td");
            let timer = document.createElement("p");
            let button = document.createElement("button");

            let name= jsonResponse[a].flight;
            let flightAirline;
            if(name.startsWith('MS')){
                flightAirline = 'Egypt Air';
            }else{
                flightAirline = 'Lufthansa';
            }

            flightnumber.appendChild(document.createTextNode(jsonResponse[a].flight));
            airline.appendChild(document.createTextNode(flightAirline)); 
            //price.appendChild(document.createTextNode(jsonResponse[a].price.toString()));
            price.appendChild(document.createTextNode("1"));
            depart.appendChild(document.createTextNode( new Date(jsonResponse[a].timestamp).toString().substring(0,28)));
            depart.classList.add("departures");
            status.classList.add("intheGreen");
            timer.classList.add("timeleft");
            depart.appendChild(timer);
            newRow.appendChild(flightnumber);
            newRow.appendChild(airline);
            newRow.append(price);
            newRow.append(depart);
            newRow.append(status);
            button.appendChild(document.createTextNode("Purchase"));
            button.classList.add("newButton");
            button.setAttribute("id", a);
            button.onclick = function() {
                let div = document.createElement("div");
                div.classList.add("loader");
                this.appendChild(div);
                console.log(contract);
                contract.flightSuretyApp.methods.buy(name, jsonResponse[a].timestamp, jsonResponse[a].airline).send({from:contract.passengers[0], value:contract.web3.utils.toWei('1', 'ether').toString(), gas:3000000},(error, result) => {
                //onsole.log("buy return");
                //console.log("buying flight");
                //console.log(result);
                purchaseFlight(error,jsonResponse[a]);
                this.removeChild(div)

            });
        
            }
            //button.setAttribute("onclick", "contract.buyTicket(flights["+a+"],true,"+contract.passengers[0]+")");
            
            select.appendChild(button)
            newRow.append(select);
            main.appendChild(newRow);
        }

        var address = document.getElementById("yourAddress");
        address.appendChild(document.createTextNode("Your address :  "+contract.passengers[0]));


        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        /*DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })*/
    
    });
    

let statusFound = [];
setInterval(function(){ 
    let timeNow =  document.getElementsByClassName("timeleft");
    let statusNow =  document.getElementsByClassName("intheGreen");
    contract.web3.eth.getBalance(contract.passengers[0],(error, result) => {
        document.getElementById("yourBalance").innerText = "Your Balance : "+ contract.web3.utils.fromWei(result, 'ether');
      });
    contract.flightSuretyApp.methods.creditAmount(contract.passengers[0]).call((error, result) => {
        console.log("credit amount");
        console.log(result);
    document.getElementById("creditAmount").innerText = "Credit Avaliable for withdraw : "+ contract.web3.utils.fromWei(result, 'ether');
    let buttonPurchase = document.createElement("button");
    buttonPurchase.appendChild(document.createTextNode("Redeem credit"));
    buttonPurchase.classList.add("newButton");
    buttonPurchase.onclick = function() {
        let div = document.createElement("div");
        div.classList.add("loader");
        //insure.appendChild(div);
        contract.flightSuretyApp.methods.payInsuree(contract.passengers[0]).call((error, result) => {
            
        if (error == null){
            console.log(result);
            //buttonPurchase.disabled = true;
        }else{
            alert(error);
        }
    });
    //this.removeChild(div)
    }
    document.getElementById("creditAmount").append(buttonPurchase);
    });
    let currentTime = (new Date).getTime();
    for(let a = 0; a < flights.length; a++){
         contract.flightSuretyApp.methods.getPassengers(flights[a].flight,flights[a].timestamp,flights[a].airline).call((error, result) => {
            //console.log("num passengers");
           // console.log(result);
         });
        contract.flightSuretyApp.methods.getFlightStatus(flights[a].flight,flights[a].timestamp,flights[a].airline).call((error, result) => {
            //console.log(flights[a].airline);
            //console.log("result");
            //console.log(result.status);
            if(result.status == 50){
                statusNow[a].style.color = "red";
                statusNow[a].innerText = "Late Other"
            }else if (result.status == 40) {
                statusNow[a].innerText = "Late Technical"
                statusNow[a].style.color = "red";
            }else if (result.status == 30) {
                statusNow[a].innerText = "Late Weather"
                statusNow[a].style.color = "red";
            }else if (result.status == 20) {
                statusNow[a].innerText = "Late Airline"
                statusNow[a].style.color = "red";
            }else if (result.status == 10) {
                statusNow[a].innerText = "On Time"
                statusNow[a].style.color = "#00ff00";
            }else{
                statusNow[a].innerText = "Unknown"
                statusNow[a].style.color = "yellow";
            }
           
            
        });
       timeNow[a].innerText = new Date(currentTime).toString().substring(0,28);
        let status = statusFound.includes(flights[a]);
        //console.log("here");
        //console.log(status);
        //console.log(flights[a].timestamp-50000);
        //console.log(currentTime);
       if (flights[a].timestamp - 50000 <= currentTime && status == false){
        console.log("I am fetching flghht status");
        contract.flightSuretyApp.methods.fetchFlightStatus(flights[a].airline,flights[a].flight,flights[a].timestamp).send({from:contract.passengers[0]},(error, result) => {
                console.log(result);
        });
        statusFound.push(flights[a])
       }else if( flights[a].timestamp <= currentTime && status == true){
           let meNewButton = document.getElementById(a);
           meNewButton.disabled = true;
           meNewButton.value = "Departed";
           meNewButton.style.backgroundColor = "#699fb7";
        
       }
    }
}, 1000);    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

function purchaseFlight(error,flight) {
    if (error == null){
    let main = DOM.elid("yourFlights");
    let newRow = document.createElement("tr");
    let flightnumber = document.createElement("td");
    let airline = document.createElement("td");
    let insure = document.createElement("button");
    let buttonT = document.createElement("td");
    let depart = document.createElement("td");
    let td = document.createElement("td");
    flightnumber.appendChild(document.createTextNode(flight.flight));
    
    depart.appendChild(document.createTextNode( new Date(flight.timestamp).toString().substring(0,28)));
    newRow.appendChild(flightnumber);

    let flightAirline;
    if(name.startsWith('MS')){
        flightAirline = 'Egypt Air';
    }else{
        flightAirline = 'Lufthansa';
    }

    //insure.appendChild(document.createTextNode("Redeem Insurance"));
    insure.classList.add("newInsure");
    insure.onclick = function() {
        let div = document.createElement("div");
        div.classList.add("loader");
        insure.appendChild(div);
        contract.flightSuretyApp.methods.payInsuree(contract.passengers[0]).call((error, result) => {
            
        if (error == null){
            insure.disabled = true;
        }else{
            alert(error);
        }
        
    });
    this.removeChild(div)
    }
    airline.appendChild(document.createTextNode(flightAirline)); 
    newRow.appendChild(airline);
    newRow.append(depart);
    buttonT.append(insure);
    newRow.append(buttonT);
    main.appendChild(newRow);
}else{
    alert(error);
}


}