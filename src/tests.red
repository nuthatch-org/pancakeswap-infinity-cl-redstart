// Native handler tests - `redstart test`. No WASM, no Docker, no Matchstick.
//
// The first two are the whole point of this port. They fire the exact shape that
// took the deployed subgraph dark on 2026-08-02 - an event for a pool that was
// never initialised - and assert the handler survives it. Under the original's
// `Pool.load(poolId)!` the first of these is a deterministic mapping abort, and
// a deployment that hits one becomes permanently unattestable.

test "REGRESSION: a swap on a pool that was never initialised does not abort" {
  PoolManager.Swap({
      id: 0x8e1c2870ae3c352d2a80be33c7c408d993f7d07e6d63d2983e3270b35a3dbc78,
      sender: 0x01,
      amount0: 1000,
      amount1: 0 - 2000,
      sqrtPriceX96: 79228162514264337593543950336,
      liquidity: 500,
      tick: 0,
      fee: 500,
      protocolFee: 0,
  })
  // Not vacuous: the handler must bail *cleanly*, writing nothing. Without
  // these two the test would pass even if it half-built a Swap entity.
  assertMissing(Swap, "0x0000000000000000000000000000000000000000000000000000000000000000-0")
  assertMissing(PoolManager, "0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b")
}

test "REGRESSION: modify liquidity on a pool that was never initialised does not abort" {
  PoolManager.ModifyLiquidity({
      id: 0x8e1c2870ae3c352d2a80be33c7c408d993f7d07e6d63d2983e3270b35a3dbc78,
      sender: 0x01,
      tickLower: 0 - 60,
      tickUpper: 60,
      liquidityDelta: 1000,
      salt: 0x00,
  })
  assertMissing(ModifyLiquidity, "0x0000000000000000000000000000000000000000000000000000000000000000-0")
  assertMissing(Tick, "0x8e1c2870ae3c352d2a80be33c7c408d993f7d07e6d63d2983e3270b35a3dbc78#-60")
}

// ---- PositionManager ----------------------------------------------------

test "a subscription is recorded against its position" {
  PositionManager.Subscription({
      _txHash: 0xaa00000000000000000000000000000000000000000000000000000000000001,
      _logIndex: 3,
      tokenId: 7,
      subscriber: 0x0A,
  })
  assertEq(Subscribe.at("0xaa00000000000000000000000000000000000000000000000000000000000001-3").tokenId, 7)
  assertEq(Subscribe.at("0xaa00000000000000000000000000000000000000000000000000000000000001-3").position, "7")
}

test "an unsubscription is recorded against its position" {
  PositionManager.Unsubscription({
      _txHash: 0xaa00000000000000000000000000000000000000000000000000000000000002,
      _logIndex: 1,
      tokenId: 7,
      subscriber: 0x0A,
  })
  assertEq(Unsubscribe.at("0xaa00000000000000000000000000000000000000000000000000000000000002-1").tokenId, 7)
}

test "a transfer creates the position and records the transfer" {
  PositionManager.Transfer({
      _txHash: 0xaa00000000000000000000000000000000000000000000000000000000000003,
      _logIndex: 0,
      from: 0x01,
      to: 0x02,
      id: 42,
  })
  assertEq(Position.at("42").tokenId, 42)
  assertEq(Transfer.at("0xaa00000000000000000000000000000000000000000000000000000000000003-0").tokenId, 42)
}

test "a second transfer moves ownership without losing the position" {
  PositionManager.Transfer({ _txHash: 0xbb01, _logIndex: 0, from: 0x01, to: 0x02, id: 42 })
  PositionManager.Transfer({ _txHash: 0xbb02, _logIndex: 0, from: 0x02, to: 0x03, id: 42 })
  assertEq(Position.at("42").tokenId, 42)
}

test "two positions in one transaction get distinct ids via logIndex" {
  PositionManager.Transfer({ _txHash: 0xcc01, _logIndex: 0, from: 0x01, to: 0x02, id: 1 })
  PositionManager.Transfer({ _txHash: 0xcc01, _logIndex: 1, from: 0x01, to: 0x02, id: 2 })
  assertEq(Transfer.at("0xcc01-0").tokenId, 1)
  assertEq(Transfer.at("0xcc01-1").tokenId, 2)
}

// ---- helpers ------------------------------------------------------------

test "safeDiv returns zero rather than dividing by zero" {
  assertEq(safeDiv(BigDecimal.fromString("5"), BigDecimal.fromString("0")), BigDecimal.fromString("0"))
  assertEq(safeDiv(BigDecimal.fromString("6"), BigDecimal.fromString("2")), BigDecimal.fromString("3"))
}

test "hexToBigInt parses with and without the 0x prefix" {
  assertEq(hexToBigInt("0xff"), BigInt.fromI32(255))
  assertEq(hexToBigInt("ff"), BigInt.fromI32(255))
  assertEq(hexToBigInt("0x0"), BigInt.zero)
}

test "exponentToBigDecimal builds the right power of ten" {
  assertEq(exponentToBigDecimal(BigInt.fromI32(0)), BigDecimal.fromString("1"))
  assertEq(exponentToBigDecimal(BigInt.fromI32(18)), BigDecimal.fromString("1000000000000000000"))
}

test "convertTokenToDecimal scales by the token's decimals" {
  assertEq(convertTokenToDecimal(BigInt.fromI32(100), BigInt.fromI32(2)), BigDecimal.fromString("1"))
  assertEq(convertTokenToDecimal(BigInt.fromI32(100), BigInt.zero), BigDecimal.fromString("100"))
}

test "fastExponentiation handles zero, one, even, odd and negative powers" {
  assertEq(fastExponentiation(BigDecimal.fromString("2"), 0), BigDecimal.fromString("1"))
  assertEq(fastExponentiation(BigDecimal.fromString("2"), 1), BigDecimal.fromString("2"))
  assertEq(fastExponentiation(BigDecimal.fromString("2"), 4), BigDecimal.fromString("16"))
  assertEq(fastExponentiation(BigDecimal.fromString("2"), 5), BigDecimal.fromString("32"))
  assertEq(fastExponentiation(BigDecimal.fromString("2"), 0 - 2), BigDecimal.fromString("0.25"))
}

test "absBD is the identity on positives and flips negatives" {
  assertEq(absBD(BigDecimal.fromString("3")), BigDecimal.fromString("3"))
  assertEq(absBD(BigDecimal.fromString("-3")), BigDecimal.fromString("3"))
}

test "bitSet reads the bits of a non-negative int" {
  assert(bitSet(1, 1))
  assert(!bitSet(2, 1))
  assert(bitSet(2, 2))
  assert(bitSet(6, 2))
  assert(bitSet(6, 4))
  assert(!bitSet(6, 1))
}

test "the BSC whitelist and stablecoin sets are what the manifest declares" {
  assert(isWhitelistToken("0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"))
  assert(isWhitelistToken(addressZero()))
  assert(!isWhitelistToken("0x00000000000000000000000000000000deadbeef"))
  assert(isStablecoin("0x55d398326f99059ff775485246999027b3197955"))
  assert(!isStablecoin("0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"))
}

test "getSqrtRatioAtTick returns Q96 at tick zero" {
  assertEq(getSqrtRatioAtTick(0), BigInt.fromString("79228162514264337593543950336"))
}

test "getSqrtRatioAtTick is monotonic across zero" {
  assert(getSqrtRatioAtTick(60) > getSqrtRatioAtTick(0))
  assert(getSqrtRatioAtTick(0 - 60) < getSqrtRatioAtTick(0))
}

test "mulDivRoundingUp rounds up on a remainder and not otherwise" {
  assertEq(mulDivRoundingUp(BigInt.fromI32(7), BigInt.fromI32(1), BigInt.fromI32(2)), BigInt.fromI32(4))
  assertEq(mulDivRoundingUp(BigInt.fromI32(8), BigInt.fromI32(1), BigInt.fromI32(2)), BigInt.fromI32(4))
}

test "getAmount0 is zero when the current tick is above the range" {
  assertEq(getAmount0(0 - 60, 60, 120, BigInt.fromI32(1000), getSqrtRatioAtTick(120)), BigInt.zero)
}

test "getAmount1 is zero when the current tick is below the range" {
  assertEq(getAmount1(0 - 60, 60, 0 - 120, BigInt.fromI32(1000), getSqrtRatioAtTick(0 - 120)), BigInt.zero)
}
