#Tests proper reversal of pending Elements when Meros creates a MeritRemoval.

#Types.
from typing import Dict, List, IO, Any

#Data class.
from python_tests.Classes.Transactions.Data import Data

#Consensus classes.
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from python_tests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from python_tests.Tests.Errors import TestError

#Meros classes.
from python_tests.Meros.Meros import MessageType
from python_tests.Meros.RPC import RPC

#Merit and Consensus verifiers.
from python_tests.Tests.Merit.Verify import verifyBlockchain
from python_tests.Tests.Consensus.Verify import verifyMeritRemoval, verifyConsensus

#JSON standard lib.
import json

def MRPACauseTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/PendingActions.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    #Datas.
    datas: List[Data] = []
    for data in vectors["datas"]:
        datas.append(Data.fromJSON(data))
    #SignedVerifications.
    verifs: List[SignedVerification] = []
    for verif in vectors["verifications"]:
        verifs.append(SignedVerification.fromJSON(verif))
    #Removal.
    removal: SignedMeritRemoval = SignedMeritRemoval.fromJSON(vectors["removal"])
    #Consensus.
    consensus: Consensus = Consensus(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
    )
    consensus.add(verifs[0])
    consensus.add(verifs[1])
    consensus.add(verifs[2])
    consensus.add(removal)
    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        vectors["blockchain"]
    )
    file.close()

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        len(blockchain.blocks) - 2
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
                rpc.meros.blockHash(blockchain.blocks[1].header.hash)
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Send the Datas.
    for data in datas:
        if rpc.meros.transaction(data) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")

    #Send the Verifications.
    for verif in verifs:
        if rpc.meros.signedElement(verif) != rpc.meros.recv():
            raise TestError("Unexpected message sent.")

    #Verify every Data has 100 Merit.
    for data in datas:
        if rpc.call("transactions", "getMerit", [data.hash.hex()]) != {
            "merit": 100
        }:
            raise TestError("Meros didn't verify Transactions with received Verifications.")

    #Send the problem Verification and verify the MeritRemoval.
    rpc.meros.signedElement(removal.se2)
    if rpc.meros.recv() != MessageType.SignedMeritRemoval.toByte() + removal.signedSerialize():
        raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 100, removal, True)

    #Verify every Data has 100 Merit.
    for data in datas:
        if rpc.call("transactions", "getMerit", [data.hash.hex()]) != {
            "merit": 0
        }:
            raise TestError("Meros didn't revert pending actions of a malicious MeritHolder.")

    #Send the next Block.
    rpc.meros.blockHeader(blockchain.blocks[-2].header)
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            pass

        elif MessageType(msg[0]) == MessageType.BlockHeader:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Update the MeritRemoval's nonce.
    removal.nonce = 3

    #Verify the Datas have the Merit they should.
    for d in range(len(datas)):
        if rpc.call("transactions", "getMerit", [datas[d].hash.hex()]) != {
            "merit": 100 if d < 3 else 0
        }:
            raise TestError("Meros didn't apply reverted pending actions of a malicious MeritHolder.")

    #Verify the MeritRemoval is now accessible with a nonce of 3.
    verifyMeritRemoval(rpc, 4, 200, removal, True)

    #Archive the MeritRemoval.
    rpc.meros.blockHeader(blockchain.blocks[-1].header)
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], byteorder = "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.last())
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            hash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == hash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.SyncingOver:
            break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)

    #Verify the MeritRemoval again.
    verifyMeritRemoval(rpc, 4, 200, removal, False)
