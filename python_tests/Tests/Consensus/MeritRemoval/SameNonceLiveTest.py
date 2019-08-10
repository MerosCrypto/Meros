#Tests proper creation and handling of a MeritRemoval when Meros receives different Elements sharing a nonce.
#The Elements are already in a MeritRemoval archived in a Block, which is synced.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from python_tests.Classes.Consensus.Element import SignedElement
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit class.
from python_tests.Classes.Merit.Merit import Merit

#TestError Exception.
from python_tests.Tests.TestError import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#BLS lib.
import blspy

#JSON standard lib.
import json

def signedVerification(
    rpc: RPC,
    sv: SignedElement
) -> None:
    rpc.meros.signedElement(sv)
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            rpc.meros.dataMissing()

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

def SameNonceLiveTest(
    rpc: RPC
) -> None:
    snFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
    snVectors: Dict[str, Any] = json.loads(snFile.read())
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(snVectors["removal"])
    consensus.add(removal)
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        Transactions(),
        consensus,
        snVectors["blockchain"]
    )
    snFile.close()

    #BLS Public Key.
    pubKey: blspy.PublicKey = blspy.PrivateKey.from_seed(b'\0').get_public_key()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks) - 1
    )

    hash: bytes = bytes()
    msg: bytes = bytes()
    height: int = 0
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Send SignedVerifications.
    signedVerification(rpc, removal.se1)
    signedVerification(rpc, removal.se2)

    #Verify the MeritRemoval.
    mrFromMeros: bytes = rpc.meros.recv()
    if mrFromMeros != (MessageType.MeritRemoval.toByte() + removal.serialize()):
        raise TestError("Meros didn't send us a Merit Removal.")

    #Send the final Block.
    rpc.meros.blockHeader(merit.blockchain.blocks[-1].header)
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the height.
    if rpc.call("merit", "getHeight") != len(merit.blockchain.blocks):
        raise TestError("Height doesn't match.")

    #Verify the difficulty.
    if merit.blockchain.difficulty != int(rpc.call("merit", "getDifficulty"), 16):
        raise TestError("Difficulty doesn't match.")

    #Verify the blocks.
    for block in merit.blockchain.blocks:
        if rpc.call("merit", "getBlock", [block.header.nonce]) != block.toJSON():
            raise TestError("Block doesn't match.")

    #Verify the Merit Holder height.
    if rpc.call("consensus", "getHeight", [pubKey.serialize().hex()]) != 1:
        raise TestError("Merit Holder height doesn't matchh.")

    #Verify the Merit Removal.
    if rpc.call("consensus", "getElement", [
        pubKey.serialize().hex(),
        0
    ]) != removal.toJSON():
        raise TestError("Merit Removal doesn't match.")

    #Verify the Live Merit.
    if rpc.call("merit", "getLiveMerit", [pubKey.serialize().hex()]) != 0:
        raise TestError("Live Merit doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != 0:
        raise TestError("Total Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [pubKey.serialize().hex()]) != 0:
        raise TestError("Merit Holder's Merit doesn't match.")
