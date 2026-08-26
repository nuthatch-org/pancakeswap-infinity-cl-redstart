// src/mappings/{poolManager,modifyLiquidity,swap}.ts - the PoolManager half,
// and the reason this port exists.
//
// The original's handleSwap opens:
//
//     const bundle = Bundle.load('1')!
//     const poolManager = PoolManager.load(poolManagerAddress)!
//     const poolId = event.params.id.toHexString()
//     const pool = Pool.load(poolId)!            // <- src/mappings/swap.ts:39
//
// On 2026-08-02, at BSC block 113581822, a Swap arrived for a pool that had no
// Pool entity. The third assertion aborted the handler. graph-node recorded a
// deterministic nonFatalError and carried on indexing to chain head, but
// `health: unhealthy` makes every response unattestable, so the gateway went
// dark for every consumer and stayed that way. Only a publisher republish fixes
// it.
//
// Below, that same load is a `match`. Writing the `!` is not possible: `load`
// returns Option<T> and the checker rejects a dereference without a match. The
// None arm logs and returns, which is exactly what the sibling handler
// handleModifyLiquidity already did by hand in the same repo - the correct code
// existed ten lines away and swap.ts simply did not use it.

handler on PoolManager.Initialize(event) {
  let poolId = event.params.id.toHexString()

  let poolManager = PoolManager.loadOrCreate(poolManagerAddress(), {
      poolCount: zeroBI(),
      txCount: zeroBI(),
      totalVolumeUSD: zeroBD(),
      totalVolumeETH: zeroBD(),
      totalFeesUSD: zeroBD(),
      totalFeesETH: zeroBD(),
      untrackedVolumeUSD: zeroBD(),
      totalValueLockedUSD: zeroBD(),
      totalValueLockedETH: zeroBD(),
      totalValueLockedUSDUntracked: zeroBD(),
      totalValueLockedETHUntracked: zeroBD(),
      owner: addressZero(),
  })

  let bundle = Bundle.loadOrCreate("1", { ethPriceUSD: zeroBD() })

  poolManager.poolCount = poolManager.poolCount + oneBI()

  // Metadata is fetched only when the token is new, as in the original: each
  // fetch is a blocking eth_call and Initialize fires for every pool.
  let token0 = getOrCreateToken(event.params.currency0)
  let token1 = getOrCreateToken(event.params.currency1)

  match token0 {
    None => {
      log.debug("handleInitialize: could not determine decimals for token0 {}", [event.params.currency0.toHexString()])
      return
    }
    Some(t0) => {
      match token1 {
        None => {
          log.debug("handleInitialize: could not determine decimals for token1 {}", [event.params.currency1.toHexString()])
          return
        }
        Some(t1) => {
          if isWhitelistToken(t0.id) {
            t1.whitelistPools = appendPool(t1.whitelistPools, poolId)
          }
          if isWhitelistToken(t1.id) {
            t0.whitelistPools = appendPool(t0.whitelistPools, poolId)
          }

          let parameters = event.params.parameters
          let pool = Pool.create(poolId, {
              createdAtTimestamp: event.block.timestamp,
              createdAtBlockNumber: event.block.number,
              token0: t0,
              token1: t1,
              feeTier: BigInt.fromI32(event.params.fee),
              liquidity: zeroBI(),
              sqrtPrice: event.params.sqrtPriceX96,
              token0Price: zeroBD(),
              token1Price: zeroBD(),
              tick: Some(BigInt.fromI32(event.params.tick)),
              parameters: parameters,
              hooksRegistration: hooksRegistrationOf(parameters),
              tickSpacing: tickSpacingOf(parameters),
              observationIndex: zeroBI(),
              volumeToken0: zeroBD(),
              volumeToken1: zeroBD(),
              volumeUSD: zeroBD(),
              untrackedVolumeUSD: zeroBD(),
              feesUSD: zeroBD(),
              txCount: zeroBI(),
              collectedFeesToken0: zeroBD(),
              collectedFeesToken1: zeroBD(),
              collectedFeesUSD: zeroBD(),
              totalValueLockedToken0: zeroBD(),
              totalValueLockedToken1: zeroBD(),
              totalValueLockedETH: zeroBD(),
              totalValueLockedUSD: zeroBD(),
              totalValueLockedUSDUntracked: zeroBD(),
              liquidityProviderCount: zeroBI(),
              hooks: event.params.hooks.toHexString(),
          })

          pool.token0Price = token0PriceFrom(pool.sqrtPrice, t0, t1)
          pool.token1Price = token1PriceFrom(pool.sqrtPrice, t0, t1)

          bundle.ethPriceUSD = getNativePriceInUSD()

          updatePoolDayData(pool, event.block.timestamp)
          updatePoolHourData(pool, event.block.timestamp)

          t1.derivedETH = findNativePerToken(t1)
          t0.derivedETH = findNativePerToken(t0)
        }
      }
    }
  }
}

handler on PoolManager.ModifyLiquidity(event) {
  let poolId = event.params.id.toHexString()

  match Pool.load(poolId) {
    None => {
      log.debug("handleModifyLiquidity: pool not found {}", [poolId])
      return
    }
    Some(pool) => {
      match PoolManager.load(poolManagerAddress()) {
        None => {
          log.debug("handleModifyLiquidity: pool manager not found {}", [poolManagerAddress()])
          return
        }
        Some(poolManager) => {
          match Token.load(pool.token0) {
            None => {
              return
            }
            Some(token0) => {
              match Token.load(pool.token1) {
                None => {
                  return
                }
                Some(token1) => {
                  let bundle = Bundle.loadOrCreate("1", { ethPriceUSD: zeroBD() })
                  let eth = bundle.ethPriceUSD

                  // The original reads `pool.tick!.toI32()`. The tick is nullable
                  // in the schema, so here it is matched; an uninitialised pool
                  // simply has no liquidity work to do.
                  match pool.tick {
                    None => {
                      log.debug("handleModifyLiquidity: pool {} has no tick", [pool.id])
                      return
                    }
                    Some(currTickBI) => {
                      let currTick = currTickBI.toI32()

                      let amount0Raw = getAmount0(event.params.tickLower, event.params.tickUpper, currTick, event.params.liquidityDelta, pool.sqrtPrice)
                      let amount1Raw = getAmount1(event.params.tickLower, event.params.tickUpper, currTick, event.params.liquidityDelta, pool.sqrtPrice)
                      let amount0 = convertTokenToDecimal(amount0Raw, token0.decimals)
                      let amount1 = convertTokenToDecimal(amount1Raw, token1.decimals)
                      let amountUSD = calculateAmountUSD(amount0, amount1, token0.derivedETH, token1.derivedETH, eth)

                      poolManager.totalValueLockedETH = poolManager.totalValueLockedETH - pool.totalValueLockedETH
                      poolManager.txCount = poolManager.txCount + oneBI()

                      token0.txCount = token0.txCount + oneBI()
                      token0.totalValueLocked = token0.totalValueLocked + amount0
                      token0.totalValueLockedUSD = token0.totalValueLocked * (token0.derivedETH * eth)

                      token1.txCount = token1.txCount + oneBI()
                      token1.totalValueLocked = token1.totalValueLocked + amount1
                      token1.totalValueLockedUSD = token1.totalValueLocked * (token1.derivedETH * eth)

                      pool.txCount = pool.txCount + oneBI()

                      // Active liquidity only moves when the position spans the
                      // pool's current tick.
                      if BigInt.fromI32(event.params.tickLower) <= currTickBI {
                        if BigInt.fromI32(event.params.tickUpper) > currTickBI {
                          pool.liquidity = pool.liquidity + event.params.liquidityDelta
                        }
                      }

                      pool.totalValueLockedToken0 = pool.totalValueLockedToken0 + amount0
                      pool.totalValueLockedToken1 = pool.totalValueLockedToken1 + amount1
                      pool.totalValueLockedETH = pool.totalValueLockedToken0 * token0.derivedETH + pool.totalValueLockedToken1 * token1.derivedETH
                      pool.totalValueLockedUSD = pool.totalValueLockedETH * eth

                      poolManager.totalValueLockedETH = poolManager.totalValueLockedETH + pool.totalValueLockedETH
                      poolManager.totalValueLockedUSD = poolManager.totalValueLockedETH * eth

                      let transaction = loadTransaction(
                        event.transaction.hash,
                        event.block.number,
                        event.block.timestamp,
                        event.transaction.gasPrice,
                      )

                      ModifyLiquidity.create(transaction.id + "-" + event.logIndex.toString(), {
                          transaction: transaction,
                          timestamp: transaction.timestamp,
                          pool: pool,
                          token0: token0,
                          token1: token1,
                          sender: Some(event.params.sender),
                          origin: event.transaction.from,
                          amount: event.params.liquidityDelta,
                          amount0: amount0,
                          amount1: amount1,
                          amountUSD: Some(amountUSD),
                          tickLower: BigInt.fromI32(event.params.tickLower),
                          tickUpper: BigInt.fromI32(event.params.tickUpper),
                          logIndex: Some(event.logIndex),
                      })

                      let lowerTick = getOrCreateTick(pool, event.params.tickLower, event.block.timestamp, event.block.number)
                      let upperTick = getOrCreateTick(pool, event.params.tickUpper, event.block.timestamp, event.block.number)

                      lowerTick.liquidityGross = lowerTick.liquidityGross + event.params.liquidityDelta
                      lowerTick.liquidityNet = lowerTick.liquidityNet + event.params.liquidityDelta
                      upperTick.liquidityGross = upperTick.liquidityGross + event.params.liquidityDelta
                      upperTick.liquidityNet = upperTick.liquidityNet - event.params.liquidityDelta

                      updateUniswapDayData(poolManager, event.block.timestamp)
                      updatePoolDayData(pool, event.block.timestamp)
                      updatePoolHourData(pool, event.block.timestamp)
                      updateTokenDayData(token0, event.block.timestamp)
                      updateTokenDayData(token1, event.block.timestamp)
                      updateTokenHourData(token0, event.block.timestamp)
                      updateTokenHourData(token1, event.block.timestamp)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

handler on PoolManager.Swap(event) {
  let poolId = event.params.id.toHexString()

  // src/mappings/swap.ts:39 was `const pool = Pool.load(poolId)!`. This is that
  // line, and the None arm is the three weeks of downtime that the `!` bought.
  match Pool.load(poolId) {
    None => {
      log.debug("handleSwap: pool not found {}", [poolId])
      return
    }
    Some(pool) => {
      match PoolManager.load(poolManagerAddress()) {
        None => {
          log.debug("handleSwap: pool manager not found {}", [poolManagerAddress()])
          return
        }
        Some(poolManager) => {
          match Token.load(pool.token0) {
            None => {
              return
            }
            Some(token0) => {
              match Token.load(pool.token1) {
                None => {
                  return
                }
                Some(token1) => {
                  let bundle = Bundle.loadOrCreate("1", { ethPriceUSD: zeroBD() })
                  let eth = bundle.ethPriceUSD

                  // amount0/amount1 are token deltas and may be either sign.
                  // Unlike V3 a negative amount means tokens sent *to* the pool,
                  // so the sign is inverted before use, as in the original.
                  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals) * negOneBD()
                  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals) * negOneBD()
                  let amount0Abs = absBD(amount0)
                  let amount1Abs = absBD(amount1)

                  let amount0USD = amount0Abs * token0.derivedETH * eth
                  let amount1USD = amount1Abs * token1.derivedETH * eth

                  // Halved because input and output cannot both count as volume.
                  let amountTotalUSDTracked = getTrackedAmountUSD(amount0Abs, token0, amount1Abs, token1) / twoBD()
                  let amountTotalETHTracked = safeDiv(amountTotalUSDTracked, eth)
                  let amountTotalUSDUntracked = (amount0USD + amount1USD) / twoBD()

                  let million = BigDecimal.fromString("1000000")
                  let feesETH = amountTotalETHTracked * pool.feeTier.toBigDecimal() / million
                  let feesUSD = amountTotalUSDTracked * pool.feeTier.toBigDecimal() / million

                  poolManager.txCount = poolManager.txCount + oneBI()
                  poolManager.totalVolumeETH = poolManager.totalVolumeETH + amountTotalETHTracked
                  poolManager.totalVolumeUSD = poolManager.totalVolumeUSD + amountTotalUSDTracked
                  poolManager.untrackedVolumeUSD = poolManager.untrackedVolumeUSD + amountTotalUSDUntracked
                  poolManager.totalFeesETH = poolManager.totalFeesETH + feesETH
                  poolManager.totalFeesUSD = poolManager.totalFeesUSD + feesUSD

                  // Reset the aggregate before the per-pool TVL update below.
                  poolManager.totalValueLockedETH = poolManager.totalValueLockedETH - pool.totalValueLockedETH

                  pool.volumeToken0 = pool.volumeToken0 + amount0Abs
                  pool.volumeToken1 = pool.volumeToken1 + amount1Abs
                  pool.volumeUSD = pool.volumeUSD + amountTotalUSDTracked
                  pool.untrackedVolumeUSD = pool.untrackedVolumeUSD + amountTotalUSDUntracked
                  pool.feesUSD = pool.feesUSD + feesUSD
                  pool.txCount = pool.txCount + oneBI()

                  pool.liquidity = event.params.liquidity
                  pool.tick = Some(BigInt.fromI32(event.params.tick))
                  pool.sqrtPrice = event.params.sqrtPriceX96
                  pool.totalValueLockedToken0 = pool.totalValueLockedToken0 + amount0
                  pool.totalValueLockedToken1 = pool.totalValueLockedToken1 + amount1

                  token0.volume = token0.volume + amount0Abs
                  token0.totalValueLocked = token0.totalValueLocked + amount0
                  token0.volumeUSD = token0.volumeUSD + amountTotalUSDTracked
                  token0.untrackedVolumeUSD = token0.untrackedVolumeUSD + amountTotalUSDUntracked
                  token0.feesUSD = token0.feesUSD + feesUSD
                  token0.txCount = token0.txCount + oneBI()

                  token1.volume = token1.volume + amount1Abs
                  token1.totalValueLocked = token1.totalValueLocked + amount1
                  token1.volumeUSD = token1.volumeUSD + amountTotalUSDTracked
                  token1.untrackedVolumeUSD = token1.untrackedVolumeUSD + amountTotalUSDUntracked
                  token1.feesUSD = token1.feesUSD + feesUSD
                  token1.txCount = token1.txCount + oneBI()

                  pool.token0Price = token0PriceFrom(pool.sqrtPrice, token0, token1)
                  pool.token1Price = token1PriceFrom(pool.sqrtPrice, token0, token1)

                  bundle.ethPriceUSD = getNativePriceInUSD()
                  let newEth = bundle.ethPriceUSD
                  token0.derivedETH = findNativePerToken(token0)
                  token1.derivedETH = findNativePerToken(token1)

                  pool.totalValueLockedETH = pool.totalValueLockedToken0 * token0.derivedETH + pool.totalValueLockedToken1 * token1.derivedETH
                  pool.totalValueLockedUSD = pool.totalValueLockedETH * newEth

                  poolManager.totalValueLockedETH = poolManager.totalValueLockedETH + pool.totalValueLockedETH
                  poolManager.totalValueLockedUSD = poolManager.totalValueLockedETH * newEth

                  token0.totalValueLockedUSD = token0.totalValueLocked * token0.derivedETH * newEth
                  token1.totalValueLockedUSD = token1.totalValueLocked * token1.derivedETH * newEth

                  let transaction = loadTransaction(
                    event.transaction.hash,
                    event.block.number,
                    event.block.timestamp,
                    event.transaction.gasPrice,
                  )

                  Swap.create(transaction.id + "-" + event.logIndex.toString(), {
                      transaction: transaction,
                      timestamp: transaction.timestamp,
                      pool: pool,
                      token0: token0,
                      token1: token1,
                      sender: event.params.sender,
                      origin: event.transaction.from,
                      amount0: amount0,
                      amount1: amount1,
                      amountUSD: amountTotalUSDTracked,
                      sqrtPriceX96: event.params.sqrtPriceX96,
                      tick: BigInt.fromI32(event.params.tick),
                      logIndex: Some(event.logIndex),
                  })

                  let uniswapDayData = updateUniswapDayData(poolManager, event.block.timestamp)
                  let poolDayData = updatePoolDayData(pool, event.block.timestamp)
                  let poolHourData = updatePoolHourData(pool, event.block.timestamp)
                  let token0DayData = updateTokenDayData(token0, event.block.timestamp)
                  let token1DayData = updateTokenDayData(token1, event.block.timestamp)
                  let token0HourData = updateTokenHourData(token0, event.block.timestamp)
                  let token1HourData = updateTokenHourData(token1, event.block.timestamp)

                  uniswapDayData.volumeETH = uniswapDayData.volumeETH + amountTotalETHTracked
                  uniswapDayData.volumeUSD = uniswapDayData.volumeUSD + amountTotalUSDTracked
                  uniswapDayData.feesUSD = uniswapDayData.feesUSD + feesUSD

                  poolDayData.volumeUSD = poolDayData.volumeUSD + amountTotalUSDTracked
                  poolDayData.volumeToken0 = poolDayData.volumeToken0 + amount0Abs
                  poolDayData.volumeToken1 = poolDayData.volumeToken1 + amount1Abs
                  poolDayData.feesUSD = poolDayData.feesUSD + feesUSD

                  poolHourData.volumeUSD = poolHourData.volumeUSD + amountTotalUSDTracked
                  poolHourData.volumeToken0 = poolHourData.volumeToken0 + amount0Abs
                  poolHourData.volumeToken1 = poolHourData.volumeToken1 + amount1Abs
                  poolHourData.feesUSD = poolHourData.feesUSD + feesUSD

                  token0DayData.volume = token0DayData.volume + amount0Abs
                  token0DayData.volumeUSD = token0DayData.volumeUSD + amountTotalUSDTracked
                  token0DayData.untrackedVolumeUSD = token0DayData.untrackedVolumeUSD + amountTotalUSDTracked
                  token0DayData.feesUSD = token0DayData.feesUSD + feesUSD

                  token0HourData.volume = token0HourData.volume + amount0Abs
                  token0HourData.volumeUSD = token0HourData.volumeUSD + amountTotalUSDTracked
                  token0HourData.untrackedVolumeUSD = token0HourData.untrackedVolumeUSD + amountTotalUSDTracked
                  token0HourData.feesUSD = token0HourData.feesUSD + feesUSD

                  token1DayData.volume = token1DayData.volume + amount1Abs
                  token1DayData.volumeUSD = token1DayData.volumeUSD + amountTotalUSDTracked
                  token1DayData.untrackedVolumeUSD = token1DayData.untrackedVolumeUSD + amountTotalUSDTracked
                  token1DayData.feesUSD = token1DayData.feesUSD + feesUSD

                  token1HourData.volume = token1HourData.volume + amount1Abs
                  token1HourData.volumeUSD = token1HourData.volumeUSD + amountTotalUSDTracked
                  token1HourData.untrackedVolumeUSD = token1HourData.untrackedVolumeUSD + amountTotalUSDTracked
                  token1HourData.feesUSD = token1HourData.feesUSD + feesUSD
                }
              }
            }
          }
        }
      }
    }
  }
}
