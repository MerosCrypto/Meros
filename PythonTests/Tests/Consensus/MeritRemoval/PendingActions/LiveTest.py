#Tests proper reversal of pending Elements when Meros receives a SignedMeritRemoval.

#Types.
from typing import Dict, List, IO, Any

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#Consensus classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit and Consensus verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval, verifyConsensus

#JSON standard lib.
import json

def MRPALiveTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/PendingActions.json", "r")
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
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )
    consensus.add(verifs[0])
    consensus.add(verifs[1])
    consensus.add(verifs[2])
    consensus.add(verifs[3])
    consensus.add(verifs[4])
    consensus.add(verifs[5])
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
    rpc.meros.connect(254, 254, 3)

    reqHash: bytes = bytes()
    msg: bytes = bytes()
    height: int = 0
    while True:
        msg = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height = int.from_bytes(msg[1 : 5], "big")
            if height == 0:
                rpc.meros.blockHash(blockchain.blocks[1].header.hash)
            else:
                if height >= len(blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 49]
            for block in blockchain.blocks:
                if block.header.hash == reqHash:
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
        if rpc.call("consensus", "getStatus", [data.hash.hex()])["merit"] != 100:
            raise TestError("Meros didn't verify Transactions with received Verifications.")

    #Send and verify the MeritRemoval.
    if rpc.meros.signedElement(removal) != rpc.meros.recv():
        raise TestError("Meros didn't send us the Merit Removal.")
    verifyMeritRemoval(rpc, 1, 100, removal, True)

    #Verify every Data has 0 Merit.
    for data in datas:
        if rpc.call("consensus", "getStatus", [data.hash.hex()])["merit"] != 0:
            raise TestError("Meros didn't revert pending actions of a malicious MeritHolder.")

    #Send the next Blocks to trigger the Epoch. The last Block also archives the MeritRemoval.
    for i in range(2, 8):
        rpc.meros.blockHeader(blockchain.blocks[i].header)
        while True:
            msg = rpc.meros.recv()

            if MessageType(msg[0]) == MessageType.Syncing:
                rpc.meros.acknowledgeSyncing()

            elif MessageType(msg[0]) == MessageType.GetBlockHash:
                height = int.from_bytes(msg[1 : 5], "big")
                if height == 0:
                    rpc.meros.blockHash(blockchain.last())
                else:
                    if height >= len(blockchain.blocks):
                        raise TestError("Meros asked for a Block Hash we do not have.")

                    rpc.meros.blockHash(blockchain.blocks[height].header.hash)

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 49]
                for block in blockchain.blocks:
                    if block.header.hash == reqHash:
                        rpc.meros.blockBody(block.body)
                        break

                    if block.header.hash == blockchain.last():
                        raise TestError("Meros asked for a Block Body we do not have.")

            elif MessageType(msg[0]) == MessageType.SyncingOver:
                if i == 7:
                    break

            elif MessageType(msg[0]) == MessageType.BlockHeader:
                break

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Datas have the Merit they should.
    for data in datas:
        if rpc.call("consensus", "getStatus", [data.hash.hex()])["merit"] != 0:
            raise TestError("Meros didn't finalize with the reverted pending actions of a malicious MeritHolder.")

    #Update the MeritRemoval's nonce.
    removal.nonce = 6

    #Verify the MeritRemoval is now accessible with a nonce of 6.
    verifyMeritRemoval(rpc, 7, 0, removal, False)

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)
