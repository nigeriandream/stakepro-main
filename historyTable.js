// initialize web3.js
const web3 = new Web3(Web3.givenProvider);

// get the contract instance
const contractAddress = '0x...'; // your contract address here
const contractAbi = [...]; // your contract ABI here
const contract = new web3.eth.Contract(contractAbi, contractAddress);

// get the user's history and populate the table
const historyTable = document.getElementById('history-table');
const tbody = historyTable.querySelector('tbody');
contract.methods.getUserHistory().call().then(events => {
    events.forEach(event => {
        const row = document.createElement('tr');
        const eventType = event.isStake ? 'Stake' : 'Unstake';
        const amount = web3.utils.fromWei(event.amount);
        const netReward = web3.utils.fromWei(event.netReward);
        const timestamp = new Date(event.timestamp * 1000).toLocaleString();
        row.innerHTML = `<td>${eventType}</td><td>${amount}</td><td>${netReward}</td><td>${timestamp}</td>`;
        tbody.appendChild(row);
    });
}).catch(console.error);


{/* <table id="history-table">
  <thead>
    <tr>
      <th>Event Type</th>
      <th>Amount</th>
      <th>Net Reward</th>
      <th>Timestamp</th>
    </tr>
  </thead>
  <tbody>
  </tbody>
</table> */}
