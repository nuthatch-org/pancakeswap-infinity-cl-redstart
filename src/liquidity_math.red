// src/utils/liquidityMath/{fullMath,sqrtPriceMath,tickMath,liquidityAmounts}.ts,
// which are themselves ports of the Uniswap v3 SDK.
//
// Two deliberate divergences from the original, both noted at the site:
//   * bit tests are arithmetic rather than `&`, since absTick is a non-negative
//     Int and `(v / bit) % 2 == 1` is exact for one;
//   * getSqrtRatioAtTick does not `throw new Error('TICK')` on an out-of-range
//     tick. Throwing is what a deterministic mapping abort *is*, and this port
//     exists because one of those took the deployment dark for three weeks. The
//     range is enforced on-chain by the PoolManager, so the branch is
//     unreachable; it clamps and logs instead of aborting the deployment.

fn minTick() -> Int {
  return 0 - 887272
}

fn maxTick() -> Int {
  return 887272
}

fn mulShift(val: BigInt, mulBy: BigInt) -> BigInt {
  return val.times(mulBy).rightShift(128)
}

// True when `bit` (a power of two) is set in the non-negative `v`.
fn bitSet(v: Int, bit: Int) -> Bool {
  return (v / bit) % 2 == 1
}

fn mulDivRoundingUp(a: BigInt, b: BigInt, denominator: BigInt) -> BigInt {
  let product = a * b
  let result = product / denominator
  if product.mod(denominator) != BigInt.zero {
    result = result + oneBI()
  }
  return result
}

fn getSqrtRatioAtTick(tick: Int) -> BigInt {
  let clamped = tick
  if clamped < minTick() {
    log.warning("getSqrtRatioAtTick: tick {} below MIN_TICK, clamping", [tick.toString()])
    clamped = minTick()
  }
  if clamped > maxTick() {
    log.warning("getSqrtRatioAtTick: tick {} above MAX_TICK, clamping", [tick.toString()])
    clamped = maxTick()
  }

  let absTick = clamped
  if clamped < 0 {
    absTick = 0 - clamped
  }

  let ratio = hexToBigInt("0x100000000000000000000000000000000")
  if bitSet(absTick, 1) {
    ratio = hexToBigInt("0xfffcb933bd6fad37aa2d162d1a594001")
  }
  if bitSet(absTick, 2) { ratio = mulShift(ratio, hexToBigInt("0xfff97272373d413259a46990580e213a")) }
  if bitSet(absTick, 4) { ratio = mulShift(ratio, hexToBigInt("0xfff2e50f5f656932ef12357cf3c7fdcc")) }
  if bitSet(absTick, 8) { ratio = mulShift(ratio, hexToBigInt("0xffe5caca7e10e4e61c3624eaa0941cd0")) }
  if bitSet(absTick, 16) { ratio = mulShift(ratio, hexToBigInt("0xffcb9843d60f6159c9db58835c926644")) }
  if bitSet(absTick, 32) { ratio = mulShift(ratio, hexToBigInt("0xff973b41fa98c081472e6896dfb254c0")) }
  if bitSet(absTick, 64) { ratio = mulShift(ratio, hexToBigInt("0xff2ea16466c96a3843ec78b326b52861")) }
  if bitSet(absTick, 128) { ratio = mulShift(ratio, hexToBigInt("0xfe5dee046a99a2a811c461f1969c3053")) }
  if bitSet(absTick, 256) { ratio = mulShift(ratio, hexToBigInt("0xfcbe86c7900a88aedcffc83b479aa3a4")) }
  if bitSet(absTick, 512) { ratio = mulShift(ratio, hexToBigInt("0xf987a7253ac413176f2b074cf7815e54")) }
  if bitSet(absTick, 1024) { ratio = mulShift(ratio, hexToBigInt("0xf3392b0822b70005940c7a398e4b70f3")) }
  if bitSet(absTick, 2048) { ratio = mulShift(ratio, hexToBigInt("0xe7159475a2c29b7443b29c7fa6e889d9")) }
  if bitSet(absTick, 4096) { ratio = mulShift(ratio, hexToBigInt("0xd097f3bdfd2022b8845ad8f792aa5825")) }
  if bitSet(absTick, 8192) { ratio = mulShift(ratio, hexToBigInt("0xa9f746462d870fdf8a65dc1f90e061e5")) }
  if bitSet(absTick, 16384) { ratio = mulShift(ratio, hexToBigInt("0x70d869a156d2a1b890bb3df62baf32f7")) }
  if bitSet(absTick, 32768) { ratio = mulShift(ratio, hexToBigInt("0x31be135f97d08fd981231505542fcfa6")) }
  if bitSet(absTick, 65536) { ratio = mulShift(ratio, hexToBigInt("0x9aa508b5b7a84e1c677de54f3e99bc9")) }
  if bitSet(absTick, 131072) { ratio = mulShift(ratio, hexToBigInt("0x5d6af8dedb81196699c329225ee604")) }
  if bitSet(absTick, 262144) { ratio = mulShift(ratio, hexToBigInt("0x2216e584f5fa1ea926041bedfe98")) }
  if bitSet(absTick, 524288) { ratio = mulShift(ratio, hexToBigInt("0x48a170391f7dc42444e8fa2")) }

  if clamped > 0 {
    ratio = maxUint256() / ratio
  }

  let shift = BigInt.fromI32(2).pow(32)
  let result = ratio / shift
  if ratio.mod(shift) > BigInt.zero {
    result = result + oneBI()
  }
  return result
}

fn getAmount0Delta(a: BigInt, b: BigInt, liquidity: BigInt, roundUp: Bool) -> BigInt {
  let lo = a
  let hi = b
  if a > b {
    lo = b
    hi = a
  }
  let numerator1 = liquidity.leftShift(96)
  let numerator2 = hi - lo
  if roundUp {
    return mulDivRoundingUp(mulDivRoundingUp(numerator1, numerator2, hi), oneBI(), lo)
  }
  return numerator1 * numerator2 / hi / lo
}

fn getAmount1Delta(a: BigInt, b: BigInt, liquidity: BigInt, roundUp: Bool) -> BigInt {
  let lo = a
  let hi = b
  if a > b {
    lo = b
    hi = a
  }
  let difference = hi - lo
  if roundUp {
    return mulDivRoundingUp(liquidity, difference, q96())
  }
  return liquidity * difference / q96()
}

fn getAmount0(tickLower: Int, tickUpper: Int, currTick: Int, amount: BigInt, currSqrtPriceX96: BigInt) -> BigInt {
  let sqrtRatioAX96 = getSqrtRatioAtTick(tickLower)
  let sqrtRatioBX96 = getSqrtRatioAtTick(tickUpper)
  let roundUp = amount > BigInt.zero

  if currTick < tickLower {
    return getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, amount, roundUp)
  }
  if currTick < tickUpper {
    return getAmount0Delta(currSqrtPriceX96, sqrtRatioBX96, amount, roundUp)
  }
  return zeroBI()
}

fn getAmount1(tickLower: Int, tickUpper: Int, currTick: Int, amount: BigInt, currSqrtPriceX96: BigInt) -> BigInt {
  let sqrtRatioAX96 = getSqrtRatioAtTick(tickLower)
  let sqrtRatioBX96 = getSqrtRatioAtTick(tickUpper)
  let roundUp = amount > BigInt.zero

  if currTick < tickLower {
    return zeroBI()
  }
  if currTick < tickUpper {
    return getAmount1Delta(sqrtRatioAX96, currSqrtPriceX96, amount, roundUp)
  }
  return getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, amount, roundUp)
}
