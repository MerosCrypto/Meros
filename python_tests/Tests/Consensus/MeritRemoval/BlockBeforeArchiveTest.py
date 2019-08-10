#Tests proper creation and handling of a MeritRemoval when Meros receives different Elements sharing a nonce.
#The first Element is in Block 1. The MeritRemoval is in Block 2.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit class.
from python_tests.Classes.Merit.Merit import Merit

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#BLS lib.
import blspy

#JSON standard lib.
import json

def BlockBeforeArchiveTest(
    rpc: RPC
) -> None:
    bbaFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/BlockBeforeArchive.json", "r")
    bbaVectors: Dict[str, Any] = json.loads(bbaFile.read())
    #Consensus.
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        bbaVectors["consensus"]
    )
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        Transactions(),
        consensus,
        bbaVectors["blockchain"]
    )
    bbaFile.close()

    #BLS Public Key.
    pubKey: blspy.PublicKey = blspy.PrivateKey.from_seed(b'\0').get_public_key()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks)
    )

    msgs: List[bytes] = []
    ress: List[bytes] = []
    sentLast: int = 2
    hash: bytes = bytes()
    while True:
        msgs.append(rpc.meros.recv())

        if MessageType(msgs[-1][0]) == MessageType.Syncing:
            ress.append(rpc.meros.acknowledgeSyncing())

        elif MessageType(msgs[-1][0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msgs[-1][1 : 5], byteorder = "big")
            if height == 0:
                ress.append(rpc.meros.blockHash(merit.blockchain.last()))
            else:
                if height >= len(merit.blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                ress.append(rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash))

        elif MessageType(msgs[-1][0]) == MessageType.BlockHeaderRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockHeader(block.header))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.BlockBodyRequest:
            hash = msgs[-1][1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    ress.append(rpc.meros.blockBody(block.body))
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Body we do not have.")

        elif MessageType(msgs[-1][0]) == MessageType.ElementRequest:
            sentLast -= 1
            ress.append(rpc.meros.element(
                consensus.holders[
                    msgs[-1][1 : 49]
                ][
                    int.from_bytes(msgs[-1][49 : 53], byteorder = "big")
                ]
            ))

        elif MessageType(msgs[-1][0]) == MessageType.TransactionRequest:
            ress.append(rpc.meros.dataMissing())

        elif MessageType(msgs[-1][0]) == MessageType.SyncingOver:
            ress.append(bytes())
            if sentLast == 0:
                break

        else:
            raise Exception("Unexpected message sent: " + msgs[-1].hex().upper())

    #Verify the height.
    if rpc.call("merit", "getHeight") != len(merit.blockchain.blocks):
        raise Exception("Height doesn't match.")

    #Verify the difficulty.
    if merit.blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise Exception("Difficulty doesn't match.")

    #Verify the blocks.
    for block in merit.blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise Exception("Block doesn't match.")

    #Verify the Merit Holder height.
    if rpc.call("consensus", "getHeight", [pubKey.serialize().hex()]) != 1:
        raise Exception("Merit Holder height doesn't matchh.")

    #Verify the Consensus
    for e in range(0, len(consensus.holders[pubKey.serialize()])):
        if rpc.call("consensus", "getElement", [
            pubKey.serialize().hex(),
            e
        ]) != consensus.holders[pubKey.serialize()][e].toJSON():
            raise Exception("Element doesn't match.")

    #Verify the Live Merit.
    if rpc.call("merit", "getLiveMerit", [pubKey.serialize().hex()]) != 0:
        raise Exception("Live Merit doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != 0:
        raise Exception("Total Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [pubKey.serialize().hex()]) != 0:
        raise Exception("Merit Holder's Merit doesn't match.")

    #Replay their messages and verify they send what we sent.
    for m in range(0, len(msgs)):
        rpc.meros.send(msgs[m])
        if len(ress[m]) != 0:
            if ress[m] != rpc.meros.recv():
                raise Exception("Invalid sync response.")

    print("Finished the Consensus/MeritRemoval/BlockBeforeArchive Test.")
