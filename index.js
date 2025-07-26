// const ws = new WebSocket('wss://ethereum-ws.chainfetch.app');
// const ws = new WebSocket('wss://eth-mainnet.g.alchemy.com/v2/demo');
const ws = new WebSocket('wss://ethereum-rpc.publicnode.com');
// const ws = new WebSocket('wss://mainnet.infura.io/ws/v3/demo');
// const ws = new WebSocket('wss://rpc.ankr.com/eth/ws');
// const ws = new WebSocket('wss://eth-mainnet.g.alchemy.com/v2/demo');
// const ws = new WebSocket('wss://mainnet.infura.io/ws/v3/demo');

ws.onopen = () => {
  // Get latest block
  ws.send(JSON.stringify({
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id": 1
  }));
  
  // Subscribe to new blocks
  ws.send(JSON.stringify({
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": ["newHeads"],
    "id": 2
  }));

  ws.send(JSON.stringify({
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": ["newPendingTransactions"],
    "id": 4
  }));
  // Subscribe to Uniswap V2 Router “Swap” events
  ws.send(JSON.stringify({
    "jsonrpc": "2.0",
    "method": "eth_subscribe",
    "params": [
      "logs",
      {
        "address": "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        "topics": [
          "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"
        ]
      }
    ],
    "id": 3
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  
  // Handle subscription setup responses
  if (data.id === 1) {
    console.log('🎯 Current block:', parseInt(data.result, 16).toLocaleString());
    return;
  }
  
  if (data.id === 2) {
    console.log('🔔 New blocks subscription:', data.result);
    return;
  }
  
  if (data.id === 3) {
    console.log('🦄 Uniswap subscription:', data.result);
    return;
  }
  
  if (data.id === 4) {
    console.log('⏳ Pending tx subscription:', data.result);
    return;
  }
  
  // Handle subscription data
  if (data.method === 'eth_subscription') {
    const result = data.params.result;
    
    // New block notification
    if (result && result.number) {
      const blockNum = parseInt(result.number, 16);
      const timestamp = parseInt(result.timestamp, 16);
      console.log(`🟢 NEW BLOCK: ${blockNum.toLocaleString()} | ${new Date(timestamp * 1000).toLocaleTimeString()}`);
      
      // Get full block details with transactions
      ws.send(JSON.stringify({
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [result.number, true], // true = include full transaction objects
        "id": `block_${blockNum}`
      }));
      return;
    }
    
    // Pending transaction hash
    if (typeof result === 'string' && result.startsWith('0x') && result.length === 66) {
      // console.log('⏳ Pending tx:', result.substring(0, 10) + '...');
      return;
    }
    
    // Uniswap swap event
    if (result && result.address) {
      console.log('🦄 Uniswap swap in block:', parseInt(result.blockNumber, 16));
      return;
    }
  }
  
  // Handle block details response
  if (data.id && data.id.startsWith('block_') && data.result && data.result.transactions) {
    const block = data.result;
    const blockNum = parseInt(block.number, 16);
    const txCount = block.transactions.length;
    
    // Calculate total ETH value
    let totalValue = 0;
    for (const tx of block.transactions) {
      totalValue += parseInt(tx.value || '0x0', 16) / 1e18;
    }
    
    console.log(`💎 BLOCK ${blockNum}: ${txCount} txs | ${totalValue.toFixed(2)} ETH total`);
    return;
  }
  
  // Handle errors
  if (data.error) {
    console.log('❌ Error:', data.error.message);
    return;
  }
  
  // Log anything else for debugging
  console.log('📨 Other:', data);
};