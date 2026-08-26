// src/utils/index.ts and src/utils/constants.ts.
//
// Redstart has no module-level constants, so ZERO_BI/ONE_BD and friends become
// `fn`s. Everything else is a direct translation; `.plus()/.times()` become the
// arithmetic operators, which is the whole of the difference.

fn zeroBI() -> BigInt {
  return BigInt.zero
}

fn oneBI() -> BigInt {
  return BigInt.fromI32(1)
}

fn zeroBD() -> BigDecimal {
  return BigDecimal.fromString("0")
}

fn oneBD() -> BigDecimal {
  return BigDecimal.fromString("1")
}

fn negOneBD() -> BigDecimal {
  return BigDecimal.fromString("-1")
}

fn twoBD() -> BigDecimal {
  return BigDecimal.fromString("2")
}

fn q96() -> BigInt {
  return BigInt.fromI32(2).pow(96)
}

fn q192() -> BigInt {
  return BigInt.fromI32(2).pow(192)
}

fn maxUint256() -> BigInt {
  return hexToBigInt("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
}

fn exponentToBigDecimal(decimals: BigInt) -> BigDecimal {
  let resultString = "1"
  let n = decimals.toI32()
  let i = 0
  while i < n {
    resultString = resultString + "0"
    i = i + 1
  }
  return BigDecimal.fromString(resultString)
}

// Return 0 rather than dividing by zero. The original's comment, kept because it
// is the reason this helper exists at all.
fn safeDiv(amount0: BigDecimal, amount1: BigDecimal) -> BigDecimal {
  if amount1 == zeroBD() {
    return zeroBD()
  }
  return amount0 / amount1
}

fn hexToBigInt(hexInput: String) -> BigInt {
  let hex = hexInput
  if hex.startsWith("0x") {
    hex = hex.slice(2)
  }
  let acc = BigInt.zero
  let sixteen = BigInt.fromI32(16)
  let i = 0
  let n = hex.length
  while i < n {
    acc = acc * sixteen + BigInt.fromI32(hexDigit(hex.charAt(i)))
    i = i + 1
  }
  return acc
}

// `parseInt(c, 16)` has no Redstart equivalent, so the table is explicit. An
// unrecognised character contributes zero, exactly as parseInt's NaN would have
// after the original's `as i32` cast.
fn hexDigit(c: String) -> Int {
  if c == "0" { return 0 }
  if c == "1" { return 1 }
  if c == "2" { return 2 }
  if c == "3" { return 3 }
  if c == "4" { return 4 }
  if c == "5" { return 5 }
  if c == "6" { return 6 }
  if c == "7" { return 7 }
  if c == "8" { return 8 }
  if c == "9" { return 9 }
  if c == "a" { return 10 }
  if c == "A" { return 10 }
  if c == "b" { return 11 }
  if c == "B" { return 11 }
  if c == "c" { return 12 }
  if c == "C" { return 12 }
  if c == "d" { return 13 }
  if c == "D" { return 13 }
  if c == "e" { return 14 }
  if c == "E" { return 14 }
  if c == "f" { return 15 }
  if c == "F" { return 15 }
  return 0
}

// Exponentiation by squaring, as in the original.
fn fastExponentiation(value: BigDecimal, power: Int) -> BigDecimal {
  if power < 0 {
    let inverted = fastExponentiation(value, 0 - power)
    return safeDiv(oneBD(), inverted)
  }
  if power == 0 {
    return oneBD()
  }
  if power == 1 {
    return value
  }
  let halfPower = power / 2
  let halfResult = fastExponentiation(value, halfPower)
  let result = halfResult * halfResult
  if power % 2 == 1 {
    result = result * value
  }
  return result
}

fn convertTokenToDecimal(tokenAmount: BigInt, exchangeDecimals: BigInt) -> BigDecimal {
  if exchangeDecimals == zeroBI() {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal() / exponentToBigDecimal(exchangeDecimals)
}

fn absBD(value: BigDecimal) -> BigDecimal {
  if value < zeroBD() {
    return value * negOneBD()
  }
  return value
}

// The original takes the whole `ethereum.Event`; Redstart helpers take the four
// fields it actually read, which also makes the dependency obvious. gasUsed is
// zero for the same reason it is in the original: it lives on the receipt, and
// no handler can see one.
fn loadTransaction(hash: Bytes, blockNumber: BigInt, timestamp: BigInt, gasPrice: BigInt) -> Transaction {
  let transaction = Transaction.loadOrCreate(hash.toHexString(), {
      blockNumber: blockNumber,
      timestamp: timestamp,
      gasUsed: BigInt.zero,
      gasPrice: gasPrice,
  })
  transaction.blockNumber = blockNumber
  transaction.timestamp = timestamp
  transaction.gasUsed = BigInt.zero
  transaction.gasPrice = gasPrice
  return transaction
}

fn eventId(transactionHash: Bytes, logIndex: BigInt) -> String {
  return transactionHash.toHexString() + "-" + logIndex.toString()
}

fn positionId(tokenId: BigInt) -> String {
  return tokenId.toString()
}

fn appendPool(pools: [String], poolId: String) -> [String] {
  let next = pools
  next.push(poolId)
  return next
}

// The Infinity pool key packs tick spacing and the hook registration bitmap into
// the trailing bytes of `parameters`. Byte offsets are the original's.
fn hooksRegistrationOf(parameters: Bytes) -> Bytes {
  return Bytes.fromUint8Array(parameters.slice(30, 32))
}

fn tickSpacingOf(parameters: Bytes) -> BigInt {
  let raw = parameters.slice(27, 30)
  raw.reverse()
  return BigInt.fromByteArray(Bytes.fromUint8Array(raw))
}

// src/utils/tick.ts, with the pool passed in rather than re-loaded by id.
fn getOrCreateTick(pool: Pool, tickIdx: Int, timestamp: BigInt, blockNumber: BigInt) -> Tick {
  let idx = BigInt.fromI32(tickIdx)
  let price0 = fastExponentiation(BigDecimal.fromString("1.0001"), tickIdx)

  return Tick.loadOrCreate(pool.id + "#" + idx.toString(), {
      poolAddress: Some(pool.id),
      tickIdx: idx,
      pool: pool,
      liquidityGross: zeroBI(),
      liquidityNet: zeroBI(),
      price0: price0,
      price1: safeDiv(oneBD(), price0),
      createdAtTimestamp: timestamp,
      createdAtBlockNumber: blockNumber,
  })
}
