// The BSC entry of the original's src/utils/chains.ts, which is a 586-line
// if/else chain over every network the subgraph can be built for.
//
// Redstart's manifest carries one network per `source` block, so this port is
// BSC-only and the branch collapses to these helpers. Porting to another network
// means changing these values, not adding a branch. Note there are no
// module-level constants in Redstart, so every constant is a `fn`.
//
// BSC's config declares empty tokenOverrides, poolsToSkip and poolMappings, so
// the code paths that consumed them are omitted rather than ported as no-ops.

fn poolManagerAddress() -> String {
  return "0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b"
}

fn stablecoinWrappedNativePoolId() -> String {
  return "0x752e76950f6167b8dbb0495b957d264d61724dfa26e3dd6fad1ba820862ce9cf"
}

fn stablecoinIsToken0() -> Bool {
  return false
}

fn wrappedNativeAddress() -> String {
  return "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
}

fn minimumNativeLocked() -> BigDecimal {
  return BigDecimal.fromString("10")
}

fn nativeSymbol() -> String {
  return "BNB"
}

fn nativeName() -> String {
  return "Binance Coin"
}

fn nativeDecimals() -> BigInt {
  return BigInt.fromI32(18)
}

// The original calls `stablecoinAddresses.includes(id)` and
// `whitelistTokens.includes(id)`. Written as explicit comparisons so the set is
// visible at the call site and no array-membership helper is needed.

fn isStablecoin(id: String) -> Bool {
  if id == "0x55d398326f99059ff775485246999027b3197955" {
    return true
  }
  if id == "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d" {
    return true
  }
  return false
}

fn isWhitelistToken(id: String) -> Bool {
  if id == "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c" {
    return true
  }
  if id == "0x55d398326f99059ff775485246999027b3197955" {
    return true
  }
  if id == "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d" {
    return true
  }
  if id == addressZero() {
    return true
  }
  return false
}

fn addressZero() -> String {
  return "0x0000000000000000000000000000000000000000"
}
