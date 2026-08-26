// src/mappings/{subscribe,unsubscribe,transfer}.ts - the PositionManager half.
//
// Nearly a mechanical translation. The one substantive change is in
// handleTransfer, where the original's load-then-null-check-then-construct
// becomes `loadOrCreate`, so the "did I remember to initialise every required
// field on the new-entity path" question is answered by the compiler.

handler on PositionManager.Subscription(event) {
  let transaction = loadTransaction(
    event.transaction.hash,
    event.block.number,
    event.block.timestamp,
    event.transaction.gasPrice,
  )

  Subscribe.create(eventId(event.transaction.hash, event.logIndex), {
      tokenId: event.params.tokenId,
      address: event.params.subscriber.toHexString(),
      transaction: transaction,
      logIndex: event.logIndex,
      timestamp: transaction.timestamp,
      origin: event.transaction.from.toHexString(),
      position: positionId(event.params.tokenId),
  })
}

handler on PositionManager.Unsubscription(event) {
  let transaction = loadTransaction(
    event.transaction.hash,
    event.block.number,
    event.block.timestamp,
    event.transaction.gasPrice,
  )

  Unsubscribe.create(eventId(event.transaction.hash, event.logIndex), {
      tokenId: event.params.tokenId,
      address: event.params.subscriber.toHexString(),
      transaction: transaction,
      logIndex: event.logIndex,
      timestamp: transaction.timestamp,
      origin: event.transaction.from.toHexString(),
      position: positionId(event.params.tokenId),
  })
}

handler on PositionManager.Transfer(event) {
  let tokenId = positionId(event.params.id)

  let position = Position.loadOrCreate(tokenId, {
      tokenId: event.params.id,
      owner: event.params.to.toHexString(),
      origin: event.transaction.from.toHexString(),
      createdAtTimestamp: event.block.timestamp,
  })
  position.owner = event.params.to.toHexString()

  let transaction = loadTransaction(
    event.transaction.hash,
    event.block.number,
    event.block.timestamp,
    event.transaction.gasPrice,
  )

  Transfer.create(eventId(event.transaction.hash, event.logIndex), {
      tokenId: event.params.id,
      from: event.params.from.toHexString(),
      to: event.params.to.toHexString(),
      transaction: transaction,
      logIndex: event.logIndex,
      timestamp: transaction.timestamp,
      origin: event.transaction.from.toHexString(),
      position: position,
  })
}
