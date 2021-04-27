
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
        var jsonResponse = JSON.parse(xmlHttp.responseText);
        flights = jsonResponse;
        let main = DOM.elid("flightInfoTable");

        //var d = new Date(0); // The 0 there is the key, which sets the date to the epoch
        for(let a = 0; a < jsonResponse.length;a++){
            jsonResponse[a].price = contract.web3.utils.fromWei(jsonResponse[a].price,'ether');
            let newRow = document.createElement("tr");
            let flightnumber = document.createElement("td");
            let airline = document.createElement("td");
            let price = document.createElement("td");
            let depart = document.createElement("td");
            let status = document.createElement("td");
            let select = document.createElement("td");
            let timer = document.createElement("p");
            let button = document.createElement("button");

            let airlines;
            if(jsonResponse[a].airline == 0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2){
                airlines = "SouthWest Airlines";
            }else if (jsonResponse[a].airline == 0x821aEa9a577a9b44299B9c15c88cf3087F3b5544){
                airlines = "Frontier Airlines";
            }else {
                airlines = "United Airlines";
            }
            flightnumber.appendChild(document.createTextNode(jsonResponse[a].flightNumber));
            airline.appendChild(document.createTextNode(airlines)); 
            price.appendChild(document.createTextNode(jsonResponse[a].price.toString()));
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
                contract.buyTicket(flights[a],true,contract.passengers[0],(error, result) => {
                purchaseFlight(error,result);
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
        
        
        contract.credit((error, result) => {
            document.getElementById("creditAmount").innerText = "Credit Avaliable for withdraw : "+result;
          });

        // Read transaction
        contract.balance((error, result) => {
          let button = document.createElement("button");
          let tag = document.getElementById("yourBalance");
          tag.innerText = "Your Balance : "+result;
          button.innerText = "Redeem Credit";
          let parent = document.getElementById("needforcredit");
          button.setAttribute("id", "credit");
          button.onclick = function() {
                let div = document.createElement("div");
                div.classList.add("loader");
                this.appendChild(div);
                contract.redeemCredit(contract.passengers[0],(error, result) => {
                this.removeChild(div)
            });
        }
          parent.appendChild(button);
          
        });
        // Read transaction
        contract.isOperational((error, result) => {
            let displayOperation = document.getElementById("operation");
                displayOperation.appendChild(DOM.p({className:'navbar-brand mediumFont'},"Operational Status : " +result));
        });
        

    });



let statusFound = [];
setInterval(function(){ 
    let timeNow =  document.getElementsByClassName("timeleft");
    let statusNow =  document.getElementsByClassName("intheGreen");
    contract.balance((error, result) => {
        document.getElementById("yourBalance").innerText = "Your Balance : "+result;
      });
    contract.credit((error, result) => {
    document.getElementById("creditAmount").innerText = "Credit Avaliable for withdraw : "+result;
    });
    let currentTime = (new Date).getTime();
    for(let a = 0; a < flights.length; a++){
        contract.getFlightStatus(flights[a], (error, result) => {
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
        let status = statusFound.includes(flights[a])
       if (flights[a].timestamp - 50000 <= currentTime && status == false){
    
        contract.fetchFlightStatus(flights[a], (error, result) => {
                //console.log(result);
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
    
    depart.appendChild(document.createTextNode( new Date(flight.timestamp * 1000) .toString().substring(0,28)));
    newRow.appendChild(flightnumber);
    let airlines;
    if(flight.airline == 0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2){
        airlines = "SouthWest Airlines";
    }else if (flight.airline == 0x821aEa9a577a9b44299B9c15c88cf3087F3b5544){
        airlines = "Frontier Airlines";
    }else {
        airlines = "United Airlines";
    }
    insure.appendChild(document.createTextNode("Redeem Insurance"));
    insure.classList.add("newInsure");
    insure.onclick = function() {
        let div = document.createElement("div");
        div.classList.add("loader");
        insure.appendChild(div);
        contract.payInsuree(flight,contract.passengers[0],(error, result) => {
            
        if (error == null){
            insure.disabled = true;
        }else{
            alert(error);
        }
        
    });
    this.removeChild(div)
    }
    airline.appendChild(document.createTextNode(airlines)); 
    newRow.appendChild(airline);
    newRow.append(depart);
    buttonT.append(insure);
    newRow.append(buttonT);
    main.appendChild(newRow);
}else{
    alert(error);
}

}


