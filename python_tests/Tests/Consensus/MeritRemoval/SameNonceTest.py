#https://github.com/MerosCrypto/Meros/issues/50

#Types.
from typing import Dict, List, IO, Any

#Merit classes.
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Merit

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#BLS lib.
import blspy

#JSON standard lib.
import json

def signedVerification(
    rpc: RPC,
    sv: SignedVerification
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
            raise Exception("Unexpected message sent: " + msg.hex().upper())

def SameNonceTest(
    rpc: RPC
) -> None:
    #Transactions.
    transactions: Transactions = Transactions()
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
    )
    #Merit.
    merit: Merit = Merit(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100
    )

    #Add a single Block to create Merit.
    bbFile: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
    merit.add(
        transactions,
        consensus,
        Block.fromJSON(blocks[0])
    )
    bbFile.close()

    #BLS Keys.
    privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
    pubKey: blspy.PublicKey = privKey.get_public_key()

    #Create two Verifications with the same nonce yet for different hashes.
    h1: bytes = b'\0' * 48
    sv1: SignedVerification = SignedVerification(h1)
    sv1.sign(privKey, 0)

    h2: bytes = b'\1' * 48
    sv2: SignedVerification = SignedVerification(h2)
    sv2.sign(privKey, 0)

    #Create the MeritRemoval.
    mr: SignedMeritRemoval = SignedMeritRemoval(0, sv1.toSignedElement(), sv2.toSignedElement())

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(merit.blockchain.blocks)
    )

    hash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise Exception("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise Exception("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise Exception("Unexpected message sent: " + msg.hex().upper())

    signedVerification(rpc, sv1)
    signedVerification(rpc, sv2)

    mrFromMeros: bytes = rpc.meros.recv()
    if mrFromMeros != (MessageType.MeritRemoval.toByte() + mr.serialize()):
        raise Exception("Meros didn't send us a Merit Removal.")

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

    #Verify the Merit Removal.
    if rpc.call("consensus", "getElement", [
        pubKey.serialize().hex(),
        0
    ]) != mr.toJSON():
        raise Exception("Merit Removal doesn't match.")

    #Verify the amount of Merit.
    if rpc.call("merit", "getTotalMerit", [pubKey.serialize().hex()]) != 0:
        raise Exception("Total Merit doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != 0:
        raise Exception("Total Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [pubKey.serialize().hex()]) != 0:
        raise Exception("Merit Holder's Merit doesn't match.")

    print("Finished the Consensus/MeritRemoval/SameNonce Test.")
