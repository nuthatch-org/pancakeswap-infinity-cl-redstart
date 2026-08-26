// src/utils/intervalUpdates.ts - the day and hour rollups.
//
// The original opens each of these with a non-null assertion:
// `PoolManager.load(poolId)!`, `Pool.load(poolId)!`, `Bundle.load('1')!`. Every
// caller already holds the entity it then re-loads by id, so this port takes the
// entity as a parameter instead. The assertions do not need matching because
// they no longer exist, which is the better fix and happens to be the one
// Redstart's type system pushes you toward.

fn updateUniswapDayData(poolManager: PoolManager, timestamp: BigInt) -> UniswapDayData {
  let ts = timestamp.toI32()
  let dayID = ts / 86400
  let dayStartTimestamp = dayID * 86400

  let dayData = UniswapDayData.loadOrCreate(dayID.toString(), {
      date: dayStartTimestamp,
      volumeETH: zeroBD(),
      volumeUSD: zeroBD(),
      volumeUSDUntracked: zeroBD(),
      feesUSD: zeroBD(),
      txCount: zeroBI(),
      tvlUSD: zeroBD(),
  })

  dayData.tvlUSD = poolManager.totalValueLockedUSD
  dayData.txCount = poolManager.txCount
  return dayData
}

fn updatePoolDayData(pool: Pool, timestamp: BigInt) -> PoolDayData {
  let ts = timestamp.toI32()
  let dayID = ts / 86400
  let dayStartTimestamp = dayID * 86400
  let dayPoolID = pool.id + "-" + dayID.toString()

  let dayData = PoolDayData.loadOrCreate(dayPoolID, {
      date: dayStartTimestamp,
      pool: pool,
      liquidity: pool.liquidity,
      sqrtPrice: pool.sqrtPrice,
      token0Price: pool.token0Price,
      token1Price: pool.token1Price,
      tick: pool.tick,
      tvlUSD: pool.totalValueLockedUSD,
      volumeToken0: zeroBD(),
      volumeToken1: zeroBD(),
      volumeUSD: zeroBD(),
      feesUSD: zeroBD(),
      txCount: zeroBI(),
      open: pool.token0Price,
      high: pool.token0Price,
      low: pool.token0Price,
      close: pool.token0Price,
  })

  if pool.token0Price > dayData.high {
    dayData.high = pool.token0Price
  }
  if pool.token0Price < dayData.low {
    dayData.low = pool.token0Price
  }

  dayData.liquidity = pool.liquidity
  dayData.sqrtPrice = pool.sqrtPrice
  dayData.token0Price = pool.token0Price
  dayData.token1Price = pool.token1Price
  dayData.close = pool.token0Price
  dayData.tick = pool.tick
  dayData.tvlUSD = pool.totalValueLockedUSD
  dayData.txCount = dayData.txCount + oneBI()
  return dayData
}

fn updatePoolHourData(pool: Pool, timestamp: BigInt) -> PoolHourData {
  let ts = timestamp.toI32()
  let hourIndex = ts / 3600
  let hourStartUnix = hourIndex * 3600
  let hourPoolID = pool.id + "-" + hourIndex.toString()

  let hourData = PoolHourData.loadOrCreate(hourPoolID, {
      periodStartUnix: hourStartUnix,
      pool: pool,
      liquidity: pool.liquidity,
      sqrtPrice: pool.sqrtPrice,
      token0Price: pool.token0Price,
      token1Price: pool.token1Price,
      tick: pool.tick,
      tvlUSD: pool.totalValueLockedUSD,
      volumeToken0: zeroBD(),
      volumeToken1: zeroBD(),
      volumeUSD: zeroBD(),
      feesUSD: zeroBD(),
      txCount: zeroBI(),
      open: pool.token0Price,
      high: pool.token0Price,
      low: pool.token0Price,
      close: pool.token0Price,
  })

  if pool.token0Price > hourData.high {
    hourData.high = pool.token0Price
  }
  if pool.token0Price < hourData.low {
    hourData.low = pool.token0Price
  }

  hourData.liquidity = pool.liquidity
  hourData.sqrtPrice = pool.sqrtPrice
  hourData.token0Price = pool.token0Price
  hourData.token1Price = pool.token1Price
  hourData.close = pool.token0Price
  hourData.tick = pool.tick
  hourData.tvlUSD = pool.totalValueLockedUSD
  hourData.txCount = hourData.txCount + oneBI()
  return hourData
}

fn updateTokenDayData(token: Token, timestamp: BigInt) -> TokenDayData {
  let ts = timestamp.toI32()
  let dayID = ts / 86400
  let dayStartTimestamp = dayID * 86400
  let tokenDayID = token.id + "-" + dayID.toString()
  let tokenPrice = token.derivedETH * ethPriceUSD()

  let dayData = TokenDayData.loadOrCreate(tokenDayID, {
      date: dayStartTimestamp,
      token: token,
      volume: zeroBD(),
      volumeUSD: zeroBD(),
      untrackedVolumeUSD: zeroBD(),
      totalValueLocked: token.totalValueLocked,
      totalValueLockedUSD: token.totalValueLockedUSD,
      priceUSD: tokenPrice,
      feesUSD: zeroBD(),
      open: tokenPrice,
      high: tokenPrice,
      low: tokenPrice,
      close: tokenPrice,
  })

  if tokenPrice > dayData.high {
    dayData.high = tokenPrice
  }
  if tokenPrice < dayData.low {
    dayData.low = tokenPrice
  }

  dayData.close = tokenPrice
  dayData.priceUSD = tokenPrice
  dayData.totalValueLocked = token.totalValueLocked
  dayData.totalValueLockedUSD = token.totalValueLockedUSD
  return dayData
}

fn updateTokenHourData(token: Token, timestamp: BigInt) -> TokenHourData {
  let ts = timestamp.toI32()
  let hourIndex = ts / 3600
  let hourStartUnix = hourIndex * 3600
  let tokenHourID = token.id + "-" + hourIndex.toString()
  let tokenPrice = token.derivedETH * ethPriceUSD()

  let hourData = TokenHourData.loadOrCreate(tokenHourID, {
      periodStartUnix: hourStartUnix,
      token: token,
      volume: zeroBD(),
      volumeUSD: zeroBD(),
      untrackedVolumeUSD: zeroBD(),
      totalValueLocked: token.totalValueLocked,
      totalValueLockedUSD: token.totalValueLockedUSD,
      priceUSD: tokenPrice,
      feesUSD: zeroBD(),
      open: tokenPrice,
      high: tokenPrice,
      low: tokenPrice,
      close: tokenPrice,
  })

  if tokenPrice > hourData.high {
    hourData.high = tokenPrice
  }
  if tokenPrice < hourData.low {
    hourData.low = tokenPrice
  }

  hourData.close = tokenPrice
  hourData.priceUSD = tokenPrice
  hourData.totalValueLocked = token.totalValueLocked
  hourData.totalValueLockedUSD = token.totalValueLockedUSD
  return hourData
}
