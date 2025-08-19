import 'dotenv/config';
import { Address, createPublicClient, createWalletClient, http, parseEther, parseUnits, parseEventLogs } from 'viem';
import { base, baseSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { createDrift } from '@delvtech/drift';
import { viemAdapter } from '@delvtech/drift-viem';
import { ReadWriteFactory, airlockAbi, DOPPLER_V4_ADDRESSES, type DopplerPreDeploymentConfig, type BeneficiaryData } from 'doppler-v4-sdk';

// =================================================================
// --- 1. FINAL & DOCUMENTATION-ALIGNED CONFIGURATION ---
// =================================================================

const TOKEN_CONFIG = {
  name: 'CHAINFETCH',
  symbol: 'CHAINFETCH',
  totalSupply: parseEther('100000000'),
  tokenURI: 'ipfs://bafkreihwqgpvxpknzyebumlcnuzprzammvh572uxajpi24e65fonhcrdhy/metadata.json',
};

const LBP_CONFIG = {
  tokensForSale: parseEther('20000000'),
  saleDurationDays: 7,
  priceRange: { startPrice: 0.10, endPrice: 0.02 },
  minProceeds: 100_000,
  maxProceeds: 2_000_000,
};

const VESTING_CONFIG = {
  amount: parseEther('30000000'),
  durationSeconds: BigInt(3 * 365 * 24 * 60 * 60),
};

const FEES_CONFIG = {
  beneficiarySplit: { daoTreasuryPercent: 60, stakingRewardsPercent: 30, integratorPercent: 10 },
  liquidityLockDurationDays: 365,
};


async function main() {
  console.log('🚀 Starting CHAINFETCH token deployment script...');

  // --- 2. ENVIRONMENT & WALLET SETUP ---
  const { RPC_URL, CHAIN_ID, PRIVATE_KEY, CORE_CONTRIBUTORS_VESTING_WALLET, DAO_TREASURY_WALLET, STAKING_REWARDS_WALLET, NUMERAIRE_TOKEN_ADDRESS, INTEGRATOR_FEE_WALLET } = process.env;

  if (!RPC_URL || !CHAIN_ID || !PRIVATE_KEY || !CORE_CONTRIBUTORS_VESTING_WALLET || !DAO_TREASURY_WALLET || !STAKING_REWARDS_WALLET || !NUMERAIRE_TOKEN_ADDRESS) {
    throw new Error('❌ Missing critical environment variables. Please check your .env file.');
  }
  const NUMERAIRE_DECIMALS = 6;

  const chain = Number(CHAIN_ID) === 8453 ? base : baseSepolia;
  const account = privateKeyToAccount(`0x${PRIVATE_KEY}` as `0x${string}`);
  console.log(`Deploying from account: ${account.address} on chainId: ${CHAIN_ID}`);

  const publicClient = createPublicClient({ chain, transport: http(RPC_URL) });
  const walletClient = createWalletClient({ chain, transport: http(RPC_URL), account });
  const drift = createDrift({ adapter: viemAdapter({ publicClient, walletClient }) });

  const ADDRS = DOPPLER_V4_ADDRESSES[Number(CHAIN_ID)];
  if (!ADDRS) throw new Error(`❌ No Doppler addresses found for chainId ${CHAIN_ID}.`);

  // --- 3. CONFIGURE POST-LBP TRADING FEES ---
  const toWad = (pct: number) => BigInt(pct) * BigInt(1e16);

  let rawBeneficiaries: BeneficiaryData[] = [
    { beneficiary: DAO_TREASURY_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.daoTreasuryPercent) },
    { beneficiary: STAKING_REWARDS_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.stakingRewardsPercent) },
  ];
  if (INTEGRATOR_FEE_WALLET) {
    rawBeneficiaries.push({ beneficiary: INTEGRATOR_FEE_WALLET as Address, shares: toWad(FEES_CONFIG.beneficiarySplit.integratorPercent) });
  }

  const factory = new ReadWriteFactory(ADDRS.airlock, drift);
  
  const sortedBeneficiaries = factory.sortBeneficiaries(rawBeneficiaries);
  
  const liquidityMigratorData = await factory.encodeV4MigratorData({
    fee: 3000,
    tickSpacing: 60,
    lockDuration: FEES_CONFIG.liquidityLockDurationDays * 24 * 60 * 60,
    beneficiaries: sortedBeneficiaries,
  });

  // --- 4. ASSEMBLE THE FINAL, DOCUMENTATION-ALIGNED DEPLOYMENT CONFIGURATION ---
  const blockTimestamp = Math.floor(Date.now() / 1000);

  const preDeploymentConfig: DopplerPreDeploymentConfig = {
    name: TOKEN_CONFIG.name,
    symbol: TOKEN_CONFIG.symbol,
    totalSupply: TOKEN_CONFIG.totalSupply,
    tokenURI: TOKEN_CONFIG.tokenURI,
    numTokensToSell: LBP_CONFIG.tokensForSale,
    blockTimestamp,
    duration: LBP_CONFIG.saleDurationDays,
    epochLength: 300,
    gamma: 840,
    tickSpacing: 60,
    fee: 200, // 2% in BIPS
    priceRange: LBP_CONFIG.priceRange,
    minProceeds: parseUnits(LBP_CONFIG.minProceeds.toString(), NUMERAIRE_DECIMALS),
    maxProceeds: parseUnits(LBP_CONFIG.maxProceeds.toString(), NUMERAIRE_DECIMALS),
    yearlyMintRate: 0n, 
    vestingDuration: VESTING_CONFIG.durationSeconds,
    recipients: [CORE_CONTRIBUTORS_VESTING_WALLET as Address],
    amounts: [VESTING_CONFIG.amount],
    integrator: (INTEGRATOR_FEE_WALLET || account.address) as Address,
    numeraire: NUMERAIRE_TOKEN_ADDRESS as Address,
    liquidityMigratorData,
  };

  // --- 5. BUILD, SIMULATE, AND DEPLOY ---
  console.log('Building deployment configuration with NO-OP GOVERNANCE...');
  
  // *** THIS IS THE FINAL, CRITICAL FIX ***
  // We are telling the SDK to use the simpler, gas-efficient governance model.
  const { createParams } = await factory.buildConfig(preDeploymentConfig, ADDRS, {
    useGovernance: false 
  });

  console.log('Validating deployment parameters via simulation...');
  await factory.simulateCreate(createParams);
  console.log(`✅ Simulation successful. Parameters are valid.`);

  console.log('Sending deployment transaction... Please wait for confirmation.');
  const txHash = await factory.create(createParams);
  console.log(`Transaction submitted with hash: ${txHash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash as `0x${string}` });
  console.log(`✅ Transaction confirmed in block: ${receipt.blockNumber?.toString()}`);

  // --- 6. FIND AND PRINT THE NEW TOKEN ADDRESS ---
  try {
    const logs = parseEventLogs({ abi: airlockAbi, logs: receipt.logs, eventName: 'Create' });
    const createLog = logs.find(log => log.transactionHash === txHash);
    if (createLog) {
        const tokenAddress = createLog.args?.asset;
        console.log('================================================================');
        console.log(`🎉 SUCCESS! CHAINFETCH TOKEN DEPLOYED! 🎉`);
        console.log(`Token Address: ${tokenAddress}`);
        console.log('================================================================');
    }
  } catch (e) {
    console.warn('Could not automatically find the new token address from logs.', e);
  }
}

main().catch((error: any) => {
  console.error(`❌ An error occurred during deployment: ${error.name}: ${error.message}`);
  if (error.metaMessages) {
    error.metaMessages.forEach((msg: any) => console.log(`  > ${msg}`));
  }
  process.exit(1);
});