from typing import IO, Dict, List, Tuple, Union, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Claim import Claim
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

sendFilter: SpamFilter = SpamFilter(3)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

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

#Create 12 Sends.
sends: List[Send] = []
sends.append(Send([(claim.hash, 0)], [(edPubKey.to_bytes(), claim.amount)]))
for _ in range(12):
  sends[-1].sign(edPrivKey)
  sends[-1].beat(sendFilter)
  transactions.add(sends[-1])

  sends.append(
    Send(
      [(sends[-1].hash, 0)],
      [(edPubKey.to_bytes(), sends[-1].outputs[0][1])]
    )
  )

#Order to verify the Transactions in.
#Dict key is holder nick.
#Dict value is list of transactions.
#Tuple's second value is miner.
orders: List[Tuple[Dict[int, List[int]], Union[PrivateKey, int]]] = [
  #Verify the first two Merit Holders.
  ({0: [0, 1]}, 0),
  #Verify 3, and then 2, while giving Merit to a second Merit Holder.
  ({0: [3, 2]}, PrivateKey(1)),
  #Verify every other TX.
  ({1: [5, 6, 9, 11, 3, 0], 0: [4, 5, 8, 7, 11, 6, 10, 9]}, 1)
]

for order in orders:
  packets: Dict[int, VerificationPacket] = {}

  for h in order[0]:
    for s in order[0][h]:
      if s not in packets:
        packets[s] = VerificationPacket(sends[s].hash, [])
      packets[s].holders.append(h)

  merit.blockchain.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200,
      list(packets.values()),
      minerID=order[1]
    ).finish(0, merit)
  )

#Close the Epoch.
for _ in range(5):
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200
    ).finish(0, merit)
  )

result: Dict[str, Any] = {
  "blockchain": merit.toJSON(),
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/Fifty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
