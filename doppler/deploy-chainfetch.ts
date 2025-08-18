import 'dotenv/config';
import { Address, createPublicClient, createWalletClient, http, parseEther, getContractEvents, decodeEventLog } from 'viem';
import { base, baseSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { createDrift } from '@delvtech/drift';
import { viemAdapter } from '@delvtech/drift-viem';
import { ReadWriteFactory, DOPPLER_V4_ADDRESSES, type DopplerPreDeploymentConfig, type BeneficiaryData } from 'doppler-v4-sdk';

// =================================================================
// --- 1. TOKEN & LBP CONFIGURATION (ADJUST THESE VALUES) ---
// =================================================================

const TOKEN_CONFIG = {
  name: 'CHAINFETCH',
  symbol: 'CHAINFETCH',
  totalSupply: parseEther('100000000'), // 100,000,000 total tokens
  tokenURI: 'ipfs://bafkreihwqgpvxpknzyebumlcnuzprzammvh572uxajpi24e65fonhcrdhy/metadata.json', // Optional: Link to your token's metadata
};

const LBP_CONFIG = {
  tokensForSale: parseEther('20000000'), // 20% of total supply for the public sale
  saleDurationDays: 7, // Duration of the price discovery LBP
  saleStartDelayDays: 0, // LBP starts 1 day from script execution. Set to 0 for immediate start.
  priceRange: {
    startPrice: 0.10, // Starting price in USD (if using USDC numeraire)
    endPrice: 0.02,   // Target floor price
  },
  // Guardrails for the raise. The sale will fail if proceeds are outside this range.
  minProceeds: parseEther('100000'),  // e.g., Target a minimum of $100k
  maxProceeds: parseEther('2000000'), // e.g., Target a maximum of $2M
};

const VESTING_CONFIG = {
  // 30% of total supply goes to the core contributors fund
  amount: parseEther('30000000'),
  // 3-year vesting period is a strong signal of long-term commitment
  durationSeconds: BigInt(3 * 365 * 24 * 60 * 60),
};

const FEES_CONFIG = {
  // Configuration for Uniswap v4 pool trading fees after the LBP migrates.
  // This split MUST sum to 100%. Doppler protocol fee is handled separately.
  // Example: 60% to DAO, 30% to Stakers, 10% to you (Integrator)
  beneficiarySplit: {
    daoTreasuryPercent: 60,
    stakingRewardsPercent: 30,
    integratorPercent: 10,
  },
  // How long the initial LBP liquidity is locked in Uniswap v4. 1 year is standard.
  liquidityLockDurationDays: 365,
};


async function main() {
  console.log('🚀 Starting CHAINFETCH token deployment script...');

  // --- 2. ENVIRONMENT & WALLET SETUP ---
  const { RPC_URL, CHAIN_ID, PRIVATE_KEY, CORE_CONTRIBUTORS_VESTING_WALLET, DAO_TREASURY_WALLET, STAKING_REWARDS_WALLET, NUMERAIRE_TOKEN_ADDRESS, INTEGRATOR_FEE_WALLET } = process.env;

  if (!RPC_URL || !CHAIN_ID || !PRIVATE_KEY || !CORE_CONTRIBUTORS_VESTING_WALLET || !DAO_TREASURY_WALLET || !STAKING_REWARDS_WALLET) {
    throw new Error('❌ Missing critical environment variables. Please check your .env file.');
  }

  const chain = Number(CHAIN_ID) === 8453 ? base : baseSepolia;
  const account = privateKeyToAccount(PRIVATE_KEY as `0x${string}`);
  console.log(`Deploying from account: ${account.address} on chainId: ${CHAIN_ID}`);

  const publicClient = createPublicClient({ chain, transport: http(RPC_URL) });
  const walletClient = createWalletClient({ chain, transport: http(RPC_URL), account });
  const drift = createDrift({ adapter: viemAdapter({ publicClient, walletClient }) });

  const ADDRS = DOPPLER_V4_ADDRESSES[Number(CHAIN_ID)];
  if (!ADDRS) throw new Error(`❌ No Doppler addresses found for chainId ${CHAIN_ID}.`);

  // --- 3. CONFIGURE POST-LBP TRADING FEES ---
  const toWad = (pct: number) => BigInt(pct) * BigInt(1e16); // Convert percentage to WAD format (1e18)

  let rawBeneficiaries: BeneficiaryData[] = [
    { beneficiary: DAO_TREASURY_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.daoTreasuryPercent) },
    { beneficiary: STAKING_REWARDS_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.stakingRewardsPercent) },
  ];
  if (INTEGRATOR_FEE_WALLET) {
    rawBeneficiaries.push({ beneficiary: INTEGRATOR_FEE_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.integratorPercent) });
  }

  // Beneficiaries must be sorted by address for the contract.
  rawBeneficiaries.sort((a, b) => a.beneficiary.toLowerCase().localeCompare(b.beneficiary.toLowerCase()));

  const factory = new ReadWriteFactory(ADDRS.airlock, ADDRS.bundler, drift);
  const liquidityMigratorData = factory.encodeV4MigratorData({
    fee: 3000, // 0.3% Uniswap v4 fee tier is standard
    tickSpacing: 60,
    lockDuration: FEES_CONFIG.liquidityLockDurationDays * 24 * 60 * 60,
    beneficiaries: rawBeneficiaries,
  });

  // --- 4. ASSEMBLE THE FULL DEPLOYMENT CONFIGURATION ---
  const blockTimestamp = Math.floor(Date.now() / 1000);

  const preDeploymentConfig: DopplerPreDeploymentConfig = {
    name: TOKEN_CONFIG.name,
    symbol: TOKEN_CONFIG.symbol,
    totalSupply: TOKEN_CONFIG.totalSupply,
    tokenURI: TOKEN_CONFIG.tokenURI,
    
    numTokensToSell: LBP_CONFIG.tokensForSale,
    blockTimestamp,
    startTimeOffset: LBP_CONFIG.saleStartDelayDays * 24 * 60 * 60,
    duration: LBP_CONFIG.saleDurationDays * 24 * 60 * 60,
    epochLength: 300, // 5-minute epochs for price adjustments
    gamma: 800, // Curve aggressiveness (standard value)
    priceRange: LBP_CONFIG.priceRange,
    
    tickSpacing: 60, // Standard for most token pairs
    fee: 20000, // 2% fee during the price-discovery LBP phase
    minProceeds: LBP_CONFIG.minProceeds,
    maxProceeds: LBP_CONFIG.maxProceeds,
    
    yearlyMintRate: 0n, // Fixed supply, no inflation
    vestingDuration: VESTING_CONFIG.durationSeconds,
    recipients: [CORE_CONTRIBUTORS_VESTING_WALLET as Address],
    amounts: [VESTING_CONFIG.amount],
    
    numPdSlugs: 15,
    integrator: (INTEGRATOR_FEE_WALLET || account.address) as Address,
    ...(NUMERAIRE_TOKEN_ADDRESS ? { numeraire: NUMERAIRE_TOKEN_ADDRESS as Address } : {}),
    liquidityMigratorData,
  };

  // --- 5. BUILD, SIMULATE, AND DEPLOY ---
  console.log('Building deployment configuration...');
  const { createParams } = factory.buildConfig(preDeploymentConfig, ADDRS);

  console.log('Simulating transaction to estimate gas...');
  const { gasEstimate } = await factory.simulateCreate(createParams);
  console.log(`✅ Simulation successful. Estimated gas: ${gasEstimate?.toString()}`);

  console.log('Sending deployment transaction... Please wait for confirmation.');
  const txHash = await factory.create(createParams);
  console.log(`Transaction submitted with hash: ${txHash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash as `0x${string}` });
  console.log(`✅ Transaction confirmed in block: ${receipt.blockNumber?.toString()}`);

  // --- 6. FIND AND PRINT THE NEW TOKEN ADDRESS ---
  try {
    const logs = await getContractEvents(publicClient, { 
      address: ADDRS.airlock,
      abi: ReadWriteFactory.ABI,
      eventName: 'Create',
      fromBlock: receipt.blockNumber,
      toBlock: receipt.blockNumber
    });
    const createLog = logs.find(log => log.transactionHash === txHash);
    if (createLog) {
        const decodedLog = decodeEventLog({ abi: ReadWriteFactory.ABI, data: createLog.data, topics: createLog.topics });
        const tokenAddress = (decodedLog.args as any)?.asset;
        console.log('================================================================');
        console.log(`🎉 SUCCESS! CHAINFETCH TOKEN DEPLOYED! 🎉`);
        console.log(`Token Address: ${tokenAddress}`);
        console.log('================================================================');
    }
  } catch (e) {
    console.warn('Could not automatically find the new token address from logs.', e);
  }
}

main().catch((e) => {
  console.error('❌ An error occurred during deployment:', e);
  process.exit(1);
});