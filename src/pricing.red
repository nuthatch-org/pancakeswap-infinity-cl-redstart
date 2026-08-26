// src/utils/pricing.ts.
//
// The original's sqrtPriceX96ToTokenPrices returns a two-element BigDecimal[]
// that callers index by position. Redstart writes arrays as literals, and a
// positional pair is worse than two named helpers anyway, so it is split into
// token0PriceFrom / token1PriceFrom. Same arithmetic, same order of operations.

fn decimalsFor(token: Token) -> BigInt {
  if token.id == addressZero() {
    return nativeDecimals()
  }
  return token.decimals
}

fn token1PriceFrom(sqrtPriceX96: BigInt, token0: Token, token1: Token) -> BigDecimal {
  let num = (sqrtPriceX96 * sqrtPriceX96).toBigDecimal()
  let denom = BigDecimal.fromString(q192().toString())
  return num / denom * exponentToBigDecimal(decimalsFor(token0)) / exponentToBigDecimal(decimalsFor(token1))
}

fn token0PriceFrom(sqrtPriceX96: BigInt, token0: Token, token1: Token) -> BigDecimal {
  return safeDiv(oneBD(), token1PriceFrom(sqrtPriceX96, token0, token1))
}

fn getNativePriceInUSD() -> BigDecimal {
  match Pool.load(stablecoinWrappedNativePoolId()) {
    Some(pool) => {
      if stablecoinIsToken0() {
        return pool.token0Price
      }
      return pool.token1Price
    }
    None => {
      return zeroBD()
    }
  }
}

fn ethPriceUSD() -> BigDecimal {
  match Bundle.load("1") {
    Some(bundle) => {
      return bundle.ethPriceUSD
    }
    None => {
      return zeroBD()
    }
  }
}

// Walk the token's whitelist pools and take the price from the one holding the
// most native-denominated liquidity. The original's `Bundle.load('1')!` here is
// another non-null assertion; the ethPriceUSD() helper above matches instead.
fn findNativePerToken(token: Token) -> BigDecimal {
  if token.id == wrappedNativeAddress() {
    return oneBD()
  }
  if token.id == addressZero() {
    return oneBD()
  }

  if isStablecoin(token.id) {
    return safeDiv(oneBD(), ethPriceUSD())
  }

  let largestLiquidityETH = zeroBD()
  let priceSoFar = zeroBD()

  for poolAddress in token.whitelistPools {
    match Pool.load(poolAddress) {
      Some(pool) => {
        if pool.liquidity > zeroBI() {
          if pool.token0 == token.id {
            match Token.load(pool.token1) {
              Some(other) => {
                let ethLocked = pool.totalValueLockedToken1 * other.derivedETH
                if ethLocked > largestLiquidityETH {
                  if ethLocked > minimumNativeLocked() {
                    largestLiquidityETH = ethLocked
                    priceSoFar = pool.token1Price * other.derivedETH
                  }
                }
              }
              None => {
              }
            }
          }
          if pool.token1 == token.id {
            match Token.load(pool.token0) {
              Some(other) => {
                let ethLocked = pool.totalValueLockedToken0 * other.derivedETH
                if ethLocked > largestLiquidityETH {
                  if ethLocked > minimumNativeLocked() {
                    largestLiquidityETH = ethLocked
                    priceSoFar = pool.token0Price * other.derivedETH
                  }
                }
              }
              None => {
              }
            }
          }
        }
      }
      None => {
      }
    }
  }

  return priceSoFar
}

// Both whitelisted: sum. One whitelisted: double that side. Neither: zero.
fn getTrackedAmountUSD(tokenAmount0: BigDecimal, token0: Token, tokenAmount1: BigDecimal, token1: Token) -> BigDecimal {
  let eth = ethPriceUSD()
  let price0USD = token0.derivedETH * eth
  let price1USD = token1.derivedETH * eth

  let white0 = isWhitelistToken(token0.id)
  let white1 = isWhitelistToken(token1.id)

  if white0 && white1 {
    return tokenAmount0 * price0USD + tokenAmount1 * price1USD
  }
  if white0 {
    return tokenAmount0 * price0USD * twoBD()
  }
  if white1 {
    return tokenAmount1 * price1USD * twoBD()
  }
  return zeroBD()
}

fn calculateAmountUSD(amount0: BigDecimal, amount1: BigDecimal, token0DerivedETH: BigDecimal, token1DerivedETH: BigDecimal, eth: BigDecimal) -> BigDecimal {
  return amount0 * (token0DerivedETH * eth) + amount1 * (token1DerivedETH * eth)
}
