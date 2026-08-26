// src/utils/token.ts - ERC-20 metadata, fetched by contract call.
//
// This is where Redstart's second guarantee shows: a contract call returns
// Result<T, _> and must be matched, so the reverted-call abort that the original
// guards with `try_*` + `.reverted` is unrepresentable rather than remembered.
//
// The original's staticTokenDefinition/tokenOverrides path is omitted: BSC's
// config declares `tokenOverrides: []`, so it never fires on this network.

fn isNullEthValue(value: String) -> Bool {
  return value == "0x0000000000000000000000000000000000000000000000000000000000000001"
}

fn fetchTokenSymbol(tokenAddress: Address) -> String {
  if tokenAddress.toHexString() == addressZero() {
    return nativeSymbol()
  }

  match ERC20.bind(tokenAddress).symbol() {
    Ok(symbol) => {
      return symbol
    }
    Err(e) => {
      // Broken pairs expose symbol() as bytes32 rather than string.
      match ERC20SymbolBytes.bind(tokenAddress).symbol() {
        Ok(raw) => {
          if isNullEthValue(raw.toHexString()) {
            return "unknown"
          }
          return raw.toString()
        }
        Err(e2) => {
          return "unknown"
        }
      }
    }
  }
}

fn fetchTokenName(tokenAddress: Address) -> String {
  if tokenAddress.toHexString() == addressZero() {
    return nativeName()
  }

  match ERC20.bind(tokenAddress).name() {
    Ok(name) => {
      return name
    }
    Err(e) => {
      match ERC20NameBytes.bind(tokenAddress).name() {
        Ok(raw) => {
          if isNullEthValue(raw.toHexString()) {
            return "unknown"
          }
          return raw.toString()
        }
        Err(e2) => {
          return "unknown"
        }
      }
    }
  }
}

fn fetchTokenTotalSupply(tokenAddress: Address) -> BigInt {
  if tokenAddress.toHexString() == addressZero() {
    return zeroBI()
  }
  match ERC20.bind(tokenAddress).totalSupply() {
    Ok(supply) => {
      return supply
    }
    Err(e) => {
      return BigInt.zero
    }
  }
}

// Returns Option because the original returns `BigInt | null` and its callers
// bail when decimals cannot be determined. Redstart makes that bail mandatory:
// handleInitialize has to match this before it can build a Token.
fn fetchTokenDecimals(tokenAddress: Address) -> Option<BigInt> {
  if tokenAddress.toHexString() == addressZero() {
    return Some(nativeDecimals())
  }
  match ERC20.bind(tokenAddress).decimals() {
    Ok(decimals) => {
      if decimals < BigInt.fromI32(255) {
        return Some(decimals)
      }
      return None
    }
    Err(e) => {
      return None
    }
  }
}

// The original inlines this twice in handleInitialize, once per currency, and
// bails when decimals cannot be determined. Returning Option makes that bail the
// caller's obligation rather than its choice.
fn getOrCreateToken(addr: Address) -> Option<Token> {
  let id = addr.toHexString()

  match Token.load(id) {
    Some(existing) => {
      return Some(existing)
    }
    None => {
      match fetchTokenDecimals(addr) {
        None => {
          return None
        }
        Some(decimals) => {
          let created = Token.create(id, {
              symbol: fetchTokenSymbol(addr),
              name: fetchTokenName(addr),
              decimals: decimals,
              totalSupply: fetchTokenTotalSupply(addr),
              volume: zeroBD(),
              volumeUSD: zeroBD(),
              untrackedVolumeUSD: zeroBD(),
              feesUSD: zeroBD(),
              txCount: zeroBI(),
              poolCount: zeroBI(),
              totalValueLocked: zeroBD(),
              totalValueLockedUSD: zeroBD(),
              totalValueLockedUSDUntracked: zeroBD(),
              derivedETH: zeroBD(),
              whitelistPools: [],
          })
          return Some(created)
        }
      }
    }
  }
}
