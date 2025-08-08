
import { showNotification } from './notifications.js';

class TokenPurchase {
  constructor() {
    this.treasuryWallet = document.querySelector('meta[name="chainfetch-treasury-wallet"]')?.content || '2NeWpzJrndtBk3gUv3ASUKydbvCJYMBa542FBL7tLVY8';
    this.rpcEndpoint = document.querySelector('meta[name="solana-endpoint"]')?.content || 'https://devnet.helius-rpc.com/?api-key=3de2b170-2a42-4523-937c-2979613ebf59';
    this.solPrice = 0;
    this.processing = false;
    this.web3 = null;
    this.init();
  }

  init() {
    setTimeout(() => {
      this.fetchSolPrice();
      this.setupListeners();
      this.checkWallet();
    }, 100);
    
    // Also check wallet connection after a longer delay in case Phantom loads slowly
    setTimeout(() => this.checkWallet(), 1000);
  }

  setupListeners() {
    document.getElementById('connectWalletButton')?.addEventListener('click', () => this.connectWallet());
    document.getElementById('buyTokensBtn')?.addEventListener('click', () => this.buyTokens());
    document.getElementById('tokenAmount')?.addEventListener('input', () => this.updatePricing());
  }

  async checkWallet() {
    if (!window.solana?.isPhantom) {
      this.showDisconnected();
      return;
    }

    try {
      // First check if already connected
      if (window.solana.isConnected && window.solana.publicKey) {
        this.showConnected(window.solana.publicKey.toString());
        return;
      }

      // Try to connect only if trusted
      const response = await window.solana.connect({ onlyIfTrusted: true });
      if (response?.publicKey) {
        this.showConnected(response.publicKey.toString());
      } else {
        this.showDisconnected();
      }
    } catch {
      this.showDisconnected();
    }
  }

  async connectWallet() {
    if (!window.solana?.isPhantom) {
      showNotification('Phantom wallet not detected. <a href="https://chromewebstore.google.com/detail/phantom/bfnaelmomeimhlpmgjnjophhpkkoljpa" target="_blank" class="underline">Install Phantom</a>.', 'error');
      setTimeout(() => location.reload(), 3000);
      return;
    }

    try {
      const response = await window.solana.connect();
      this.showConnected(response.publicKey.toString());
    } catch {
      showNotification('Failed to connect wallet.', 'error');
    }
  }

  showConnected(publicKey) {
    const connectBtn = document.getElementById('connectWalletButton');
    const buyBtn = document.getElementById('buyTokensBtn');
    
    if (connectBtn) {
      connectBtn.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4 mr-2">
          <path d="M20 6L9 17l-5-5"></path>
        </svg>
        Wallet Connected
      `;
      connectBtn.disabled = true;
      connectBtn.className = 'flex items-center px-4 py-2 bg-transparent border border-yellow-500/30 font-semibold rounded-md cursor-not-allowed transition-all duration-200';
      connectBtn.onclick = null;
    }
    
    if (buyBtn) {
      buyBtn.disabled = false;
      buyBtn.className = 'group relative flex md:w-auto w-full justify-center items-center gap-3 px-8 py-4 rounded-xl text-lg font-bold bg-gradient-to-r from-yellow-500 to-red-500 text-white transition-all duration-200 hover:shadow-[0_0_20px_rgba(234,179,8,0.3)] shadow-lg overflow-hidden cursor-pointer';
    }

    document.getElementById('token-purchase-container')?.style.setProperty('display', 'block');
    document.getElementById('no-wallet-message')?.style.setProperty('display', 'none');

    // Send public key to server
    fetch('/app/set_solana_key', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ public_key: publicKey })
    }).catch(() => {});
  }

  showDisconnected() {
    const connectBtn = document.getElementById('connectWalletButton');
    const buyBtn = document.getElementById('buyTokensBtn');
    
    if (connectBtn) {
      connectBtn.innerHTML = `
        <span class="relative z-10 flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 108 108" fill="none" class="mr-2">
            <path d="M80.9629 36.4777C73.2524 23.4191 58.1452 17.6191 42.7734 21.966C27.4015 26.3129 16.7734 40.1191 16.7734 55.9777V71.5191C16.7734 75.2691 19.8524 78.3777 23.5734 78.3777H30.9734C34.6943 78.3777 37.7734 75.2691 37.7734 71.5191V62.4777C37.7734 58.7277 40.8524 55.6191 44.5734 55.6191H55.5734C71.3734 55.6191 84.1734 42.6777 80.9629 36.4777Z" fill="white"/>
            <path d="M52.1734 32.0191C51.0943 32.0191 50.2734 32.8691 50.2734 33.9777C50.2734 35.0863 51.0943 35.9363 52.1734 35.9363C53.2524 35.9363 54.0734 35.0863 54.0734 33.9777C54.0734 32.8691 53.2524 32.0191 52.1734 32.0191Z" fill="white"/>
            <path d="M63.1734 32.0191C62.0943 32.0191 61.2734 32.8691 61.2734 33.9777C61.2734 35.0863 62.0943 35.9363 63.1734 35.9363C64.2524 35.9363 65.0734 35.0863 65.0734 33.9777C65.0734 32.8691 64.2524 32.0191 63.1734 32.0191Z" fill="white"/>
          </svg>
          Connect Solana Phantom Wallet
        </span>
        <span class="absolute inset-0 bg-gradient-to-r from-red-500 to-yellow-500 transition-transform duration-200 translate-x-full group-hover:translate-x-0"></span>
      `;
      connectBtn.disabled = false;
      connectBtn.className = 'group relative px-4 py-2 bg-gradient-to-r from-yellow-500 to-red-500 text-white rounded-md font-semibold transition-all duration-200 hover:shadow-[0_0_20px_rgba(234,179,8,0.3)] overflow-hidden text-sm hover:cursor-pointer';
    }
    
    if (buyBtn) {
      buyBtn.disabled = true;
      buyBtn.className = 'group relative flex md:w-auto w-full justify-center items-center gap-3 px-8 py-4 rounded-xl text-lg font-bold bg-gradient-to-r from-gray-400 to-gray-600 text-gray-300 cursor-not-allowed opacity-50 overflow-hidden';
    }

    document.getElementById('token-purchase-container')?.style.setProperty('display', 'none');
    document.getElementById('no-wallet-message')?.style.setProperty('display', 'block');
  }

  async fetchSolPrice() {
    try {
      const response = await fetch('/app/sol_price');
      const data = await response.json();
      if (data.sol_price_usd) {
        this.solPrice = data.sol_price_usd;
        this.updatePricing();
      }
    } catch {}
  }

  updatePricing() {
    const tokenAmount = parseInt(document.getElementById('tokenAmount')?.value) || 0;
    const solElement = document.getElementById('solPrice');
    const usdElement = document.getElementById('usdPrice');
    
    if (tokenAmount && this.solPrice && solElement) {
      const usdAmount = (tokenAmount / 1000) * 1; // $1 per 1000 tokens
      const solAmount = usdAmount / this.solPrice;
      solElement.textContent = `≈ ${solAmount.toFixed(6)} SOL`;
      if (usdElement) usdElement.textContent = `≈ $${usdAmount.toFixed(2)}`;
    }
  }

  async buyTokens() {
    if (this.processing || !window.solana?.isConnected) return;
    
    const tokenAmount = parseInt(document.getElementById('tokenAmount')?.value);
    if (!tokenAmount || tokenAmount <= 0 || tokenAmount % 3000 !== 0) {
      showNotification('Enter valid token amount (multiple of 3000)', 'error');
      return;
    }

    this.processing = true;
    const buyBtn = document.getElementById('buyTokensBtn');
    if (buyBtn) buyBtn.innerHTML = '<span class="animate-spin">⏳</span> Processing...';

    try {
      await this.loadWeb3();
      const { Connection, PublicKey, SystemProgram, Transaction } = this.web3;

      const connection = new Connection(this.rpcEndpoint, 'confirmed');
      const fromPubkey = new PublicKey(window.solana.publicKey.toString());
      const toPubkey = new PublicKey(this.treasuryWallet);

      const usdAmount = (tokenAmount / 1000) * 1;
      const solAmount = usdAmount / this.solPrice;
      const lamports = Math.floor(solAmount * 1_000_000_000);

      const { blockhash, lastValidBlockHeight } = await connection.getLatestBlockhash();
      
      const transaction = new Transaction().add(
        SystemProgram.transfer({ fromPubkey, toPubkey, lamports })
      );
      transaction.feePayer = fromPubkey;
      transaction.recentBlockhash = blockhash;

      const signedTx = await window.solana.signTransaction(transaction);
      const signature = await connection.sendRawTransaction(signedTx.serialize());
      
      await connection.confirmTransaction({ signature, blockhash, lastValidBlockHeight }, 'confirmed');

      const record = await this.createRecord(tokenAmount, solAmount, signature);
      if (record?.success) {
        showNotification(`Purchased ${tokenAmount} credits!`, 'success');
        this.updateCredits(record.new_credit);
      }
      
    } catch (error) {
      const msg = error.message?.includes('User rejected') ? 'Transaction cancelled.' :
                  error.message?.includes('Insufficient') ? 'Insufficient SOL balance.' :
                  'Transaction failed.';
      showNotification(msg, 'error');
    } finally {
      if (buyBtn) buyBtn.innerHTML = `
        <span class="relative z-10 flex items-center gap-3">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <path d="M12 6v6l4 2"></path>
          </svg>
          Pay with SOL
        </span>
        <span class="absolute inset-0 bg-gradient-to-r from-red-500 to-yellow-500 transition-transform duration-200 translate-x-full group-hover:translate-x-0"></span>
      `;
      this.processing = false;
    }
  }

  async loadWeb3() {
    if (this.web3) return;
    
    try {
      this.web3 = await import('https://cdn.jsdelivr.net/npm/@solana/web3.js/+esm');
    } catch {
      await new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/@solana/web3.js@latest/lib/index.iife.min.js';
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
      });
      this.web3 = window.solanaWeb3;
    }
  }

  async createRecord(tokenAmount, solAmount, signature) {
    const response = await fetch('/app/buy_token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        token_purchase: { token_amount: tokenAmount, sol_amount: solAmount, transaction_signature: signature }
      })
    });
    
    if (response.ok) return response.json();
    throw new Error((await response.json()).error || 'Server error');
  }

  updateCredits(newCredit) {
    const creditSpan = document.querySelector('#user_credit span');
    if (creditSpan) creditSpan.textContent = `${newCredit.toLocaleString()} Credits`;
    
    const dashCredit = document.getElementById('dashboard_credit');
    if (dashCredit) dashCredit.textContent = newCredit.toLocaleString();
  }
}

document.addEventListener('turbo:load', () => {
  window.tokenPurchaseInstance = new TokenPurchase();
});

export default TokenPurchase; 