from typing import Dict, List, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = Merit.fromJSON(PrototypeChain(49).toJSON())
transactions: Transactions = Transactions()

privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
pubKey: bytes = privKey.get_verifying_key().to_bytes()

recipientPriv: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)
recipientPub: bytes = recipientPriv.get_verifying_key().to_bytes()

olderClaim: Claim = Claim([(merit.mints[-2], 0)], pubKey)
olderClaim.sign(PrivateKey(0))
transactions.add(olderClaim)

newerClaim: Claim = Claim([(merit.mints[-1], 0)], pubKey)
newerClaim.sign(PrivateKey(0))
transactions.add(newerClaim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(olderClaim.hash, [0]), VerificationPacket(newerClaim.hash, [0])]
  ).finish(0, merit)
)

coreMerit: List[Dict[str, Any]] = merit.toJSON()

send: Send = Send(
  [(olderClaim.hash, 0)],
  [(recipientPub, 1), (pubKey, olderClaim.amount - 1)]
)
send.sign(privKey)
send.beat(SpamFilter(3))
transactions.add(send)

otherRecipient: bytes = ed25519.SigningKey(b'\2' * 32).get_verifying_key().to_bytes()

spendingSend: Send = Send([(send.hash, 0)], [(otherRecipient, 1)])
spendingSend.sign(recipientPriv)
spendingSend.beat(SpamFilter(3))
transactions.add(spendingSend)

#Used by the basic and immediately spent tests.
#Staggered finalization.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(send.hash, [0])]
  ).finish(0, merit)
)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(spendingSend.hash, [0])]
  ).finish(0, merit)
)

for _ in range(5):
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(0, merit)
  )

heightToBeat: int = len(coreMerit)
def reorgPast(
  mint: bytes
) -> Merit:
  #Safe due to performing the shallower reorg first.
  while coreMerit[-1]["hash"] != mint.hex().upper():
    del coreMerit[-1]
  del coreMerit[-1]

  newMerit: Merit = Merit.fromJSON(coreMerit)
  #pylint: disable=global-statement
  global heightToBeat
  while len(newMerit.blockchain.blocks) <= heightToBeat:
    newMerit.add(
      PrototypeBlock(
        #Use a slightly faster time differential.
        newMerit.blockchain.blocks[-1].header.time +
        ((newMerit.blockchain.blocks[-1].header.time - newMerit.blockchain.blocks[-2].header.time) - 1)
      ).finish(1, newMerit)
    )
  heightToBeat = len(newMerit.blockchain.blocks)
  return newMerit

#blocksWithout... are solely used by the reorg test.
#newerMintClaim is used by the reorg test and Personal's AddressRecovery test.
#It may be best to split this out with a common parent generator.
with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "send": send.toJSON(),
    "spendingSend": spendingSend.toJSON(),
    "newerMintClaim": newerClaim.toJSON(),
    "blocksWithoutNewerMint": reorgPast(newerClaim.inputs[0][0]).toJSON(),
    "blocksWithoutOlderMint": reorgPast(olderClaim.inputs[0][0]).toJSON()
  }))
