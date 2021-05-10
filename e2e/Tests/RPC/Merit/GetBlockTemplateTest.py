from typing import Dict, List, Any
import time
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Libs.RandomX import RandomX
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

#Sleep to the next second, giving almost an entire second for clock-based operations.
def nextSecond() -> float:
  startTime: float = time.time()
  time.sleep(1 - (startTime - int(startTime)))
  return time.time()

def getMiner(
  k: int
) -> str:
  return PrivateKey(k).toPublicKey().serialize().hex()

#pylint: disable=too-many-statements,too-many-locals
def getBlockTemplateTest(
  rpc: RPC
) -> None:
  edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
  edPubKey: bytes = edPrivKey.get_verifying_key()
  blockchain: Blockchain = Blockchain()

  #Get multiple templates to verify they share an ID if they're requested within the same second.
  templates: List[Dict[str, Any]] = []
  startTime: float = nextSecond()
  for k in range(5):
    templates.append(rpc.call("merit", "getBlockTemplate", {"miner": getMiner(k)}, False))
  if int(startTime) != int(time.time()):
    #Testing https://github.com/MerosCrypto/Meros/issues/278 has a much more forgiving timer of < 1 second each.
    #That said, this test was written on the fair assumption of all the above taking place in a single second.
    raise Exception("getBlockTemplate is incredibly slow, to the point an empty Block template takes > 0.2 seconds to grab, invalidating this test.")

  for k, template in zip(range(5), templates):
    if template["id"] != int(startTime):
      raise TestError("Template ID isn't the time.")

    #Also check general accuracy.
    if bytes.fromhex(template["key"]) != blockchain.genesis:
      raise TestError("Template has the wrong RandomX key.")

    bytesHeader: bytes = bytes.fromhex(template["header"])
    serializedHeader: bytes = BlockHeader(
      0,
      blockchain.blocks[0].header.hash,
      bytes(32),
      0,
      bytes(4),
      bytes(32),
      PrivateKey(k).toPublicKey().serialize(),
      int(startTime)
    ).serialize()[:-52]
    #Skip over the randomized sketch salt.
    if (bytesHeader[:72] + bytesHeader[76:]) != (serializedHeader[:72] + serializedHeader[76:]):
      raise TestError("Template has an invalid header.")
    #Difficulty modified as this is a new miner.
    if template["difficulty"] != (blockchain.difficulty() * 11 // 10):
      raise TestError("Template's difficulty is wrong.")

  currTime: int = int(nextSecond())
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": getMiner(0)}, False)
  if template["id"] != currTime:
    raise TestError("Template ID wasn't advanced with the time.")

  #Override the ID to enable easy comparison against a historical template.
  template["id"] = int(startTime)

  if int.from_bytes(bytes.fromhex(template["header"])[-4:], "little") != currTime:
    raise TestError("The header has the wrong time.")
  template["header"] = (
    bytes.fromhex(template["header"])[:72] +
    #Use the header we'll compare to's salt.
    bytes.fromhex(templates[0]["header"])[72 : 76] +
    bytes.fromhex(template["header"])[76 : -4] +
    #Also use its time.
    int(startTime).to_bytes(4, "little")
  ).hex().upper()

  if template != templates[0]:
    raise TestError("Template, minus the time difference, doesn't match the originally provided template.")

  #Test that the templates are deleted whenever a new Block appears.
  #This is done by checking the error given when we use an old template.
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    block: Block = Block.fromJSON(json.loads(file.read())[0])
    blockchain.add(block)
    rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
    rpc.meros.syncConnect(blockchain.blocks[0].header.hash)
    rpc.meros.liveBlockHeader(block.header)
    rpc.meros.rawBlockBody(block, 0)
    time.sleep(1)
  #Sanity check.
  if rpc.call("merit", "getHeight", auth=False) != 2:
    raise Exception("Didn't successfully send Meros the Block.")

  #Get a new template so Meros realizes the template situation has changed.
  rpc.call("merit", "getBlockTemplate", {"miner": getMiner(0)}, False)

  try:
    rpc.call("merit", "publishBlock", {"id": int(startTime), "header": ""}, False)
    raise Exception("")
  except Exception as e:
    if str(e) != "-2 Invalid ID.":
      raise TestError("Meros didn't delete old template IDs.")

  #Test VerificationPacket inclusion.
  data: Data = Data(bytes(32), edPubKey)
  data.sign(edPrivKey)
  data.beat(SpamFilter(5))
  verif: SignedVerification = SignedVerification(data.hash)
  verif.sign(0, PrivateKey(0))
  packet = VerificationPacket(data.hash, [0])

  rpc.meros.liveTransaction(data)
  rpc.meros.signedElement(verif)
  time.sleep(1)
  if bytes.fromhex(
    rpc.call(
      "merit",
      "getBlockTemplate",
      {"miner": getMiner(0)},
      False
    )["header"]
  )[36:68] != BlockHeader.createContents([packet]):
    raise TestError("Meros didn't include the Verification in its new template.")

  #Test Element inclusion.
  sendDiff: SignedSendDifficulty = SignedSendDifficulty(0, 0)
  sendDiff.sign(0, PrivateKey(0))
  rpc.meros.signedElement(sendDiff)
  time.sleep(1)
  if bytes.fromhex(
    rpc.call(
      "merit",
      "getBlockTemplate",
      {"miner": getMiner(0)},
      False
    )["header"]
  )[36:68] != BlockHeader.createContents([packet], [sendDiff]):
    raise TestError("Meros didn't include the Element in its new template.")

  #The 88 test checks for the non-inclusion of Verifications with unmentioned predecessors.
  #Test for non-inclusion of Elements with unmentioned predecessors.
  sendDiffChild: SignedSendDifficulty = SignedSendDifficulty(0, 2)
  sendDiffChild.sign(0, PrivateKey(0))
  rpc.meros.signedElement(sendDiffChild)
  time.sleep(1)
  if bytes.fromhex(
    rpc.call(
      "merit",
      "getBlockTemplate",
      {"miner": getMiner(0)},
      False
    )["header"]
  )[36:68] != BlockHeader.createContents([packet], [sendDiff]):
    raise TestError("Meros did include an Element with an unmentioned parent in its new template.")

  #If we send a block with a time in the future, yet within FTL (of course), make sure Meros can still generate a template.
  #Naively using the current time will create a negative clock, which isn't allowed.
  #Start by closing the sockets to give us time to work.
  rpc.meros.live.connection.close()
  rpc.meros.sync.connection.close()
  #Sleep to reset the connection state.
  time.sleep(35)

  #Create and mine the Block.
  header: BlockHeader = BlockHeader(
    0,
    blockchain.blocks[-1].header.hash,
    bytes(32),
    0,
    bytes(4),
    bytes(32),
    PrivateKey(0).toPublicKey().serialize(),
    0,
  )
  miningStart: int = 0
  #If this block takes longer than 10 seconds to mine, try another.
  #Low future time (20 seconds) is chosen due to feasibility + supporting lowering the FTL in the future.
  while time.time() > miningStart + 10:
    miningStart = int(time.time())
    header = BlockHeader(
      0,
      blockchain.blocks[-1].header.hash,
      bytes(32),
      0,
      bytes(4),
      bytes(32),
      #Mod by something is due to a 2-byte limit (IIRC -- Kayaba).
      #100 is just clean. +11 ensures an offset from the above, which really shouldn't be necessary.
      #If we did need one, +1 should work, as we only ever work with PrivateKey(0) on the blockchain.
      PrivateKey((miningStart % 100) + 10).toPublicKey().serialize(),
      int(time.time()) + 20,
    )
    header.mine(PrivateKey((miningStart % 100) + 10), blockchain.difficulty() * 11 // 10)
  blockchain.add(Block(header, BlockBody()))

  #Send it and verify it.
  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)
  rpc.meros.liveBlockHeader(header)
  rpc.meros.rawBlockBody(Block(header, BlockBody()), 0)
  rpc.meros.live.connection.close()
  rpc.meros.sync.connection.close()
  time.sleep(1)

  #Ensure a stable template ID.
  currTime = int(nextSecond())
  template = rpc.call(
    "merit",
    "getBlockTemplate",
    {"miner": getMiner(0)},
    False
  )
  if template["id"] != currTime:
    raise TestError("Template ID isn't the time when the previous Block is in the future.")
  if int.from_bytes(bytes.fromhex(template["header"])[-4:], "little") != (header.time + 1):
    raise TestError("Meros didn't handle generating a template off a Block in the future properly.")

  #Verify a Block with three Elements from a holder, where two form a Merit Removal.
  #Only the two which cause a MeritRemoval should be included.
  #Mine a Block to a new miner and clear the current template with it (might as well).
  #Also allows us to test template clearing.
  template: Dict[str, Any] = rpc.call("merit", "getBlockTemplate", {"miner": getMiner(1)}, False)
  #Mine the Block.
  proof: int = -1
  tempHash: bytes = bytes()
  tempSignature: bytes = bytes()
  while (
    (proof == -1) or
    ((int.from_bytes(tempHash, "little") * (blockchain.difficulty() * 11 // 10)) > int.from_bytes(bytes.fromhex("FF" * 32), "little"))
  ):
    proof += 1
    tempHash = RandomX(bytes.fromhex(template["header"]) + proof.to_bytes(4, "little"))
    tempSignature = PrivateKey(1).sign(tempHash).serialize()
    tempHash = RandomX(tempHash + tempSignature)
  rpc.call("merit", "publishBlock", {"id": template["id"], "header": template["header"] + proof.to_bytes(4, "little").hex() + tempSignature.hex()})
  time.sleep(1)

  #Verify the template was cleared.
  currTime = int(nextSecond())
  bytesHeader: bytes = bytes.fromhex(rpc.call("merit", "getBlockTemplate", {"miner": getMiner(0)}, False)["header"])
  serializedHeader: bytes = BlockHeader(
    0,
    tempHash,
    bytes(32),
    0,
    bytes(4),
    bytes(32),
    0,
    #Ensures that the previous time manipulation doesn't come back to haunt us.
    max(currTime, blockchain.blocks[-1].header.time + 1)
  ).serialize()[:-52]
  #Skip over the randomized sketch salt and time (which we don't currently have easy access to).
  if (bytesHeader[:72] + bytesHeader[76:-4]) != (serializedHeader[:72] + serializedHeader[76:-4]):
    raise TestError("Template wasn't cleared.")

  #Sleep so we can reconnect.
  time.sleep(35)
  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)

  #Finally create the Elements.
  dataDiff: SignedDataDifficulty = SignedDataDifficulty(1, 0)
  dataDiff.sign(2, PrivateKey(1))
  rpc.meros.signedElement(dataDiff)
  sendDiffs: List[SignedSendDifficulty] = [
    SignedSendDifficulty(1, 1),
    SignedSendDifficulty(2, 1)
  ]
  for sd in sendDiffs:
    sd.sign(2, PrivateKey(1))
    rpc.meros.signedElement(sd)
  time.sleep(1)

  #`elem for elem` is used below due to Pyright not handling inheritance properly when nested.
  #pylint: disable=unnecessary-comprehension
  if bytes.fromhex(
    rpc.call(
      "merit",
      "getBlockTemplate",
      {"miner": getMiner(0)},
      False
    )["header"]
  )[36:68] != BlockHeader.createContents([], [elem for elem in sendDiffs[::-1]]):
    raise TestError("Meros didn't include just the malicious Elements in its new template.")
