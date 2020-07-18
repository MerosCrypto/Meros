from typing import IO, Dict, List, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = PrototypeChain.withMint()
transactions: Transactions = Transactions()

sendFilter: SpamFilter = SpamFilter(3)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKeys: List[ed25519.VerifyingKey] = [
  edPrivKey.get_verifying_key(),
  ed25519.SigningKey(b'\1' * 32).get_verifying_key()
]

#Create the Claim.
claim: Claim = Claim([(merit.mints[-1].hash, 0)], edPubKeys[0].to_bytes())
claim.amount = merit.mints[-1].outputs[0][1]
claim.sign(PrivateKey(0))
transactions.add(claim)
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(claim.hash, [0])]
  ).finish(0, merit)
)

#Give the second key pair Merit.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    minerID=PrivateKey(1)
  ).finish(0, merit)
)

#Create two competing Sends.
packets: List[VerificationPacket] = []
for i in range(2):
  send: Send = Send(
    [(claim.hash, 0)],
    [(
      edPubKeys[i].to_bytes(),
      Claim.fromTransaction(transactions.txs[claim.hash]).amount
    )]
  )
  send.sign(edPrivKey)
  send.beat(sendFilter)
  transactions.add(send)

  packets.append(VerificationPacket(send.hash, [i]))

#Archive the Packets and close the Epoch.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=packets,
    minerID=0
  ).finish(0, merit)
)
#As far as I can tell, this should be range(5).
#That said, I rather have an extra Block than change the generated vector.
#A semantic JSON diff checker can be used to verify moving to 5 is fine, as long as the output is eyed over.
#Until someone does that, leave this as range(6).
#-- Kayaba
for _ in range(6):
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200
    ).finish(0, merit)
  )

result: Dict[str, Any] = {
  "blockchain": merit.toJSON(),
  "transactions": transactions.toJSON(),
  "verified": packets[0].hash.hex().upper(),
  "beaten": packets[1].hash.hex().upper()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/Competing.json", "w")
vectors.write(json.dumps(result))
vectors.close()
