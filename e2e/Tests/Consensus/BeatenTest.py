#Creates X and Y where both have a Verification on chain. Y also has one in the mempool.
#Also Z, descendant of X, which doesn't have a Verification on chain.
#Verifies:
#- When X is beaten, Y is also marked as beaten.
#- Y's pending Verification is dropped from the Block Template.
#- Z is pruned.
#- Neither X nor Y can have Transactions appended to their trees.
#- Y cannot have a Verification added via either a SignedVerification nor a Block.

from typing import Dict, List, Any
from time import sleep
import json

from pytest import raises

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Transactions.Transactions import Send, Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.Block import Block

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import MessageException, TestError

def BeatenTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Beaten.json", "r") as file:
    vectors = json.loads(file.read())
  sends: List[Send] = [Send.fromJSON(send) for send in vectors["sends"]]
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])

  #Used to get the Block Template.
  blsPubKey: str = PrivateKey(0).toPublicKey().serialize().hex()

  def sendSends() -> None:
    for send in sends[:4]:
      if rpc.meros.liveTransaction(send) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Send.")
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast a Verification.")

  #Sanity check to verify the Block Template contains the Verification.
  def verifyTemplate() -> None:
    if bytes.fromhex(
      rpc.call("merit", "getBlockTemplate", [blsPubKey])["header"]
    )[36:68] != BlockHeader.createContents([VerificationPacket(sends[2].hash, [1])]):
      raise TestError("Meros didn't add a SignedVerification to the Block Template.")

  def verifyBeaten() -> None:
    #Verify beaten was set. The fourth Transaction is also beaten, yet should be pruned.
    #That's why we don't check its status.
    for send in sends[1:3]:
      if not rpc.call("consensus", "getStatus", [send.hash.hex()])["beaten"]:
        raise TestError("Meros didn't mark a child and its descendant as beaten.")

    #Check the pending Verification for the beaten descendant was deleted.
    if (
      (rpc.call("consensus", "getStatus", [sends[2].hash.hex()])["verifiers"] != [0]) or
      (
        bytes.fromhex(
          rpc.call("merit", "getBlockTemplate", [blsPubKey])["header"]
        )[36:68] != bytes(32)
      )
    ):
      raise TestError("Block template still has the Verification.")

    #Verify the fourth Transaction was pruned.
    with raises(TestError):
      rpc.call("transactions", "getTransaction", [sends[3].hash.hex()])

    #Verify neither the second or third Transaction tree can be appended to.
    #Publishes a never seen-before Send for the descendant.
    #Re-broadcasts the pruned Transaction for the parent.
    for send in sends[3:]:
      #Most of these tests use a socket connection for this.
      #This has identical effects, returns an actual error instead of a disconnect,
      #and doesn't force us to wait a minute for our old socket to be cleared.
      with raises(TestError):
        rpc.call("transactions", "publishSend", [send.serialize().hex()])

    #Not loaded above as it can only be loqaded after the chain starts, which is done by the Liver.
    #RandomX cache keys and all that.
    blockWBeatenVerif: Block = Block.fromJSON(vectors["blockWithBeatenVerification"])

    #The following code used to test behavior which was removed, in order to be more forgiving for nodes a tad behind.

    #Verify we can't add that SignedVerification now.
    #rpc.meros.signedElement(verif)
    #try:
    #  rpc.meros.live.recv()
    #  #Hijacks a random Exception type for our purposes.
    #  raise MessageException("Meros didn't disconnect us after we sent a Verification for a beaten Transaction.")
    #except TestError:
    #  pass
    #except MessageException as e:
    #  raise TestError(e.message)
    #sleep(65)
    #rpc.meros.liveConnect(blockWBeatenVerif.header.last)

    #Verify we can't add a Block containing that Verification.
    rpc.meros.liveBlockHeader(blockWBeatenVerif.header)

    #BlockBody sync request.
    rpc.meros.handleBlockBody(blockWBeatenVerif)

    #Sketch hash sync request.
    hashReqs: bytes = rpc.meros.sync.recv()[37:]
    for h in range(0, len(hashReqs), 8):
      for packet in blockWBeatenVerif.body.packets:
        if int.from_bytes(
          hashReqs[h : h + 8],
          byteorder="little"
        ) == Sketch.hash(blockWBeatenVerif.header.sketchSalt, packet):
          rpc.meros.packet(packet)
          break

    try:
      rpc.meros.live.recv()
      raise MessageException("Meros didn't disconnect us after we sent a Block containing a Verification of a beaten Transaction.")
    except TestError:
      pass
    except MessageException as e:
      raise TestError(e.message)

    sleep(65)
    rpc.meros.liveConnect(blockWBeatenVerif.header.last)
    rpc.meros.syncConnect(blockWBeatenVerif.header.last)

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      42: sendSends,
      43: verifyTemplate,
      48: verifyBeaten
    }
  ).live()
