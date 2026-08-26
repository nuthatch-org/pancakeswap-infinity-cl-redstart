// PancakeSwap Infinity CL - a Redstart port of
// https://github.com/NgoKimPhu/infinity-cl-subgraph (deployment
// QmVjXU7yQNyyLphPGqoz8iBzqu5YXphooFJn15JqZ6ZMFz), which has been unqueryable
// through The Graph's gateway since 2026-08-02.
//
// The original died on one line: `const pool = Pool.load(poolId)!` at
// src/mappings/swap.ts:39. A Swap arrived for a pool with no Pool entity, the
// non-null assertion aborted the handler, and although the deployment kept
// indexing to chain head, health: unhealthy made every response unattestable.
//
// In Redstart that line cannot be written. `load` returns Option<T> and the
// checker refuses to let you touch the value without matching it, so the bug is
// a compile error rather than three weeks of dark. See pool_manager.red.

mod schema;
mod config;
mod math;
mod tokens;
mod pricing;
mod intervals;
mod liquidity_math;
mod pool_manager;
mod position_manager;
mod tests;

abi PoolManagerAbi from "./abis/PoolManager.json"
abi PositionManagerAbi from "./abis/PositionManager.json"
abi ERC20 from "./abis/ERC20.json"
abi ERC20NameBytes from "./abis/ERC20NameBytes.json"
abi ERC20SymbolBytes from "./abis/ERC20SymbolBytes.json"

source PoolManager {
  abi: PoolManagerAbi
  network: "bsc"
  address: 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b
  startBlock: 47214308
}

source PositionManager {
  abi: PositionManagerAbi
  network: "bsc"
  address: 0x55f4c8abA71A1e923edC303eb4fEfF14608cC226
  startBlock: 47215015
}
