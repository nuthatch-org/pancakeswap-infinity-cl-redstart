// Entities for the PancakeSwap Infinity CL subgraph.
//
// A direct translation of schema.graphql from
// https://github.com/NgoKimPhu/infinity-cl-subgraph. Ids stay in their original
// string form on purpose: changing an id changes entity identity and would break
// every query already written against the deployed subgraph. Redstart's W040
// warning about `Id<Bytes>` being cheaper is correct and deliberately accepted.

entity PoolManager {
  id: Id<String>
  poolCount: BigInt
  txCount: BigInt
  totalVolumeUSD: BigDecimal
  totalVolumeETH: BigDecimal
  totalFeesUSD: BigDecimal
  totalFeesETH: BigDecimal
  untrackedVolumeUSD: BigDecimal
  totalValueLockedUSD: BigDecimal
  totalValueLockedETH: BigDecimal
  totalValueLockedUSDUntracked: BigDecimal
  totalValueLockedETHUntracked: BigDecimal
  owner: String
}

entity Bundle {
  id: Id<String>
  ethPriceUSD: BigDecimal
}

entity Token {
  id: Id<String>
  symbol: String
  name: String
  decimals: BigInt
  totalSupply: BigInt
  volume: BigDecimal
  volumeUSD: BigDecimal
  untrackedVolumeUSD: BigDecimal
  feesUSD: BigDecimal
  txCount: BigInt
  poolCount: BigInt
  totalValueLocked: BigDecimal
  totalValueLockedUSD: BigDecimal
  totalValueLockedUSDUntracked: BigDecimal
  derivedETH: BigDecimal
  whitelistPools: [String]
  tokenDayData: [TokenDayData] derived from token
}

entity Pool {
  id: Id<String>
  createdAtTimestamp: BigInt
  createdAtBlockNumber: BigInt
  token0: Token
  token1: Token
  feeTier: BigInt
  liquidity: BigInt
  sqrtPrice: BigInt
  token0Price: BigDecimal
  token1Price: BigDecimal
  tick: Option<BigInt>
  parameters: Bytes
  hooksRegistration: Bytes
  tickSpacing: BigInt
  observationIndex: BigInt
  volumeToken0: BigDecimal
  volumeToken1: BigDecimal
  volumeUSD: BigDecimal
  untrackedVolumeUSD: BigDecimal
  feesUSD: BigDecimal
  txCount: BigInt
  collectedFeesToken0: BigDecimal
  collectedFeesToken1: BigDecimal
  collectedFeesUSD: BigDecimal
  totalValueLockedToken0: BigDecimal
  totalValueLockedToken1: BigDecimal
  totalValueLockedETH: BigDecimal
  totalValueLockedUSD: BigDecimal
  totalValueLockedUSDUntracked: BigDecimal
  liquidityProviderCount: BigInt
  hooks: String
  poolHourData: [PoolHourData] derived from pool
  poolDayData: [PoolDayData] derived from pool
  modifyLiquiditys: [ModifyLiquidity] derived from pool
  swaps: [Swap] derived from pool
  ticks: [Tick] derived from pool
}

entity Tick {
  id: Id<String>
  poolAddress: Option<String>
  tickIdx: BigInt
  pool: Pool
  liquidityGross: BigInt
  liquidityNet: BigInt
  price0: BigDecimal
  price1: BigDecimal
  createdAtTimestamp: BigInt
  createdAtBlockNumber: BigInt
}

entity Transaction {
  id: Id<String>
  blockNumber: BigInt
  timestamp: BigInt
  gasUsed: BigInt
  gasPrice: BigInt
  modifyLiquiditys: [ModifyLiquidity] derived from transaction
  swaps: [Swap] derived from transaction
  transfers: [Transfer] derived from transaction
  subscriptions: [Subscribe] derived from transaction
  unsubscriptions: [Unsubscribe] derived from transaction
}

entity Swap {
  id: Id<String>
  transaction: Transaction
  timestamp: BigInt
  pool: Pool
  token0: Token
  token1: Token
  sender: Bytes
  origin: Bytes
  amount0: BigDecimal
  amount1: BigDecimal
  amountUSD: BigDecimal
  sqrtPriceX96: BigInt
  tick: BigInt
  logIndex: Option<BigInt>
}

entity ModifyLiquidity {
  id: Id<String>
  transaction: Transaction
  timestamp: BigInt
  pool: Pool
  token0: Token
  token1: Token
  sender: Option<Bytes>
  origin: Bytes
  amount: BigInt
  amount0: BigDecimal
  amount1: BigDecimal
  amountUSD: Option<BigDecimal>
  tickLower: BigInt
  tickUpper: BigInt
  logIndex: Option<BigInt>
}

entity UniswapDayData {
  id: Id<String>
  date: Int
  volumeETH: BigDecimal
  volumeUSD: BigDecimal
  volumeUSDUntracked: BigDecimal
  feesUSD: BigDecimal
  txCount: BigInt
  tvlUSD: BigDecimal
}

entity PoolDayData {
  id: Id<String>
  date: Int
  pool: Pool
  liquidity: BigInt
  sqrtPrice: BigInt
  token0Price: BigDecimal
  token1Price: BigDecimal
  tick: Option<BigInt>
  tvlUSD: BigDecimal
  volumeToken0: BigDecimal
  volumeToken1: BigDecimal
  volumeUSD: BigDecimal
  feesUSD: BigDecimal
  txCount: BigInt
  open: BigDecimal
  high: BigDecimal
  low: BigDecimal
  close: BigDecimal
}

entity PoolHourData {
  id: Id<String>
  periodStartUnix: Int
  pool: Pool
  liquidity: BigInt
  sqrtPrice: BigInt
  token0Price: BigDecimal
  token1Price: BigDecimal
  tick: Option<BigInt>
  tvlUSD: BigDecimal
  volumeToken0: BigDecimal
  volumeToken1: BigDecimal
  volumeUSD: BigDecimal
  feesUSD: BigDecimal
  txCount: BigInt
  open: BigDecimal
  high: BigDecimal
  low: BigDecimal
  close: BigDecimal
}

entity TokenDayData {
  id: Id<String>
  date: Int
  token: Token
  volume: BigDecimal
  volumeUSD: BigDecimal
  untrackedVolumeUSD: BigDecimal
  totalValueLocked: BigDecimal
  totalValueLockedUSD: BigDecimal
  priceUSD: BigDecimal
  feesUSD: BigDecimal
  open: BigDecimal
  high: BigDecimal
  low: BigDecimal
  close: BigDecimal
}

entity TokenHourData {
  id: Id<String>
  periodStartUnix: Int
  token: Token
  volume: BigDecimal
  volumeUSD: BigDecimal
  untrackedVolumeUSD: BigDecimal
  totalValueLocked: BigDecimal
  totalValueLockedUSD: BigDecimal
  priceUSD: BigDecimal
  feesUSD: BigDecimal
  open: BigDecimal
  high: BigDecimal
  low: BigDecimal
  close: BigDecimal
}

entity Position {
  id: Id<String>
  tokenId: BigInt
  owner: String
  origin: String
  createdAtTimestamp: BigInt
  subscriptions: [Subscribe] derived from position
  unsubscriptions: [Unsubscribe] derived from position
  transfers: [Transfer] derived from position
}

entity Subscribe {
  id: Id<String>
  tokenId: BigInt
  address: String
  transaction: Transaction
  logIndex: BigInt
  timestamp: BigInt
  origin: String
  position: Position
}

entity Unsubscribe {
  id: Id<String>
  tokenId: BigInt
  address: String
  transaction: Transaction
  logIndex: BigInt
  timestamp: BigInt
  origin: String
  position: Position
}

entity Transfer {
  id: Id<String>
  tokenId: BigInt
  from: String
  to: String
  transaction: Transaction
  logIndex: BigInt
  timestamp: BigInt
  origin: String
  position: Position
}
