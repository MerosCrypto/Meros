#Unfortunately, as this works on the premise of the node being used by a miner, this can't be vectored.

#Types.
from typing import Dict, Any
from time import sleep
from hashlib import sha512

from ed25519 import SigningKey
from bip_utils import Bip39SeedGenerator

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Merit classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Consensus classes.
from e2e.Classes.Consensus.Verification import SignedVerification

from e2e.Classes.Transactions.Mint import Mint
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Data import Data

#TestError Exception.
from e2e.Tests.Errors import TestError

#Meros classes.
from e2e.Meros.RPC import RPC

def HundredSeventySevenTest(
  rpc: RPC
) -> None:
  #Grab the keys.
  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMiner")))
  blsPubKey: PublicKey = blsPrivKey.toPublicKey()

  edPrivKey: bytearray = bytearray(
    sha512(
      Bip39SeedGenerator(
        rpc.call("personal", "getMnemonic")
      ).Generate()[0 : 32]
    ).digest()
  )
  edPrivKey[0] = edPrivKey[0] & (~0b00000111)
  edPrivKey[31] = edPrivKey[31] & (~0b10000000)
  edPrivKey[31] = edPrivKey[31] | 0b01000000
  edPubKey: bytes = SigningKey(bytes(edPrivKey)).get_verifying_key().to_bytes()

  #Faux Blockchain used to calculate the difficulty.
  blockchain: Blockchain = Blockchain()

  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)

  #Mine 8 Blocks.
  #The first creates the initial Data.
  #The next 6 pop it from the Epochs.
  #One more is to verify the next is popped as well.
  for b in range(0, 8):
    template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", [blsPubKey.serialize().hex()])
    template["header"] = bytes.fromhex(template["header"])

    header: BlockHeader = BlockHeader(
      0,
      template["header"][4 : 36],
      template["header"][36 : 68],
      int.from_bytes(template["header"][68 : 70], byteorder="big"),
      template["header"][70 : 74],
      template["header"][74 : 106],
      0,
      int.from_bytes(template["header"][-4:], byteorder="big")
    )
    if b == 0:
      header.newMiner = True
      header.minerKey = blsPubKey.serialize()
    else:
      header.newMiner = False
      header.minerNick = 0

    if header.serializeHash()[:-4] != template["header"]:
      raise TestError("Failed to recreate the header.")

    header.mine(blsPrivKey, blockchain.difficulty())

    if len(rpc.meros.live.recv()) == 0:
      rpc.meros.liveConnect(blockchain.blocks[-1].header.hash)
    blockchain.add(Block(header, BlockBody()))

    rpc.call(
      "merit",
      "publishBlock",
      [
        template["id"],
        (
          template["header"] +
          header.proof.to_bytes(4, byteorder="big") +
          header.signature +
          bytes.fromhex(template["body"])
        ).hex()
      ]
    )

    if rpc.meros.live.recv() != rpc.meros.liveBlockHeader(header):
        raise TestError("Meros didn't broadcast the BlockHeader.")

    #If there's supposed to be a Mint, verify Meros claimed it.
    if b >= 6:
      #Artificially create the Mint since the Blockchain won't create one without a recreated BlockBody.
      #It's faster to create a faux Mint than to handle the BlockBodies.
      mint: Mint = Mint(header.hash, [(0, 50000)])

      claim: Claim = Claim([(mint.hash, 0)], edPubKey)
      claim.sign([blsPrivKey])
      if rpc.meros.live.recv() != rpc.meros.liveTransaction(claim):
        raise TestError("Meros didn't claim its Mint.")

    #Create the matching Data.
    data: Data = Data(blockchain.genesis, header.hash)
    #Make sure Meros broadcasts a valid Verification for it.
    verif: SignedVerification = SignedVerification(data.hash)
    verif.sign(0, blsPrivKey)
    if rpc.meros.live.recv() != rpc.meros.signedElement(verif):
      raise TestError("Meros didn't verify the Block's Data.")

    sleep(3)
