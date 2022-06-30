solc ./contracts/*.sol --optimize --optimize-runs 200  --combined-json abi,bin > ./contracts/contracts.json
node test.js
