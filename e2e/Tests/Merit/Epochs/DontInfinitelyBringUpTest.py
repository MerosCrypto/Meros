#Tests sending B in Block X, then sending child(B), then sending competitor(B).
#All three should be moved into a new Epoch.

from typing import Dict, List, Any
from time import sleep
import json

from e2e.Tests.Errors import MessageException

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Transactions.Transactions import Data, Transactions
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def DontInfinitelyBringUpTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/Epochs/DontInfinitelyBringUp.json", "r") as file:
    vectors = json.loads(file.read())
  datas: List[Data] = [Data.fromJSON(data) for data in vectors["datas"]]
  verif: SignedVerification = SignedVerification.fromSignedJSON(vectors["verification"])
  #Create a Blockchain to set the RandomX key so the below Block load doesn't error.
  _: Blockchain = Blockchain()
  bringUpBlock: Block = Block.fromJSON(vectors["bringUpBlock"])

  def verifyFinalized(
    finalized: bool
  ) -> None:
    if rpc.call("consensus", "getStatus", {"hash": datas[0].hash.hex()})["finalized"] != finalized:
      raise TestError("Meros didn't correctly finalize a Transaction.")

  def sendOtherCompetitor() -> None:
    if rpc.meros.liveTransaction(datas[1]) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us back the Data.")

    #Send a SignedVerification in order to give Meros template data.
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't send us back the Verification.")

  def attemptInvalidBringUp() -> None:
    #Verify Meros doesn't suggest the above Verification in a template.
    if bytes.fromhex(
      rpc.call("merit", "getBlockTemplate", {"miner": PrivateKey(0).toPublicKey().serialize().hex()})["header"]
    )[36 : 68] != bytes(32):
      raise TestError("Block template has the Verification.")

    #Verify we can't add a Block containing a Verification which would bring up a Transaction added more than 5 Blocks ago.
    rpc.meros.liveBlockHeader(bringUpBlock.header)

    #BlockBody sync request.
    rpc.meros.handleBlockBody(bringUpBlock)

    #Sketch hash sync request.
    hashReqs: bytes = rpc.meros.sync.recv()[37:]
    for h in range(0, len(hashReqs), 8):
      for packet in bringUpBlock.body.packets:
        if int.from_bytes(
          hashReqs[h : h + 8],
          byteorder="little"
        ) == Sketch.hash(bringUpBlock.header.sketchSalt, packet):
          rpc.meros.packet(packet)
          break

    try:
      rpc.meros.live.recv()
      raise MessageException("Meros didn't disconnect us after we sent a Block containing a Verification which would bring up an old Transaction.")
    except TestError:
      pass
    except MessageException as e:
      raise TestError(e.message)

    #Reconnect.
    rpc.meros.live.connection.close()
    rpc.meros.sync.connection.close()
    sleep(35)
    rpc.meros.liveConnect(Blockchain().last())
    rpc.meros.syncConnect(Blockchain().last())

  def prunedOtherCompetitor() -> None:
    for function in [["transactions", "getTransaction"], ["consensus", "getStatus"]]:
      try:
        rpc.call(function[0], function[1], {"hash": datas[1].hash.hex()})
        raise MessageException("Transaction wasn't pruned.")
      except TestError as e:
        #IndexError RPC error.
        if e.message[:2] != "-2":
          raise Exception("Unexpected RPC error when checking if a Transaction was pruned.")
      except MessageException as e:
        raise TestError(e.message)

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      #Presumed last Block pre-finalization. Also send the other competitor.
      #We could send the other competitor after the next Block, before we send the invalid Block.
      #That said, after the next Block, the Transaction is worthless. It can never have Verifications added.
      #A future update to Meros should ignore it then and there, so this future proofs the test.
      #Uses an array in order to call multiple functions despite being a single line lambda.
      6: lambda: [verifyFinalized(False), sendOtherCompetitor()],
      #Presumed finalization, if this Block didn't bring it forward.
      #Also attempt the invalid Block which once again attempts to bring up.
      7: lambda: [verifyFinalized(False), attemptInvalidBringUp()],
      #New last Block pre-finalization.
      11: lambda: verifyFinalized(False),
      #New finalization. Also check the Transaction which didn't have Verifications added was pruned.
      #We have another test for this, PruneUnaddable, yet it's beneficial to check here as well.
      12: lambda: [verifyFinalized(True), prunedOtherCompetitor()]
    }
  ).live()
