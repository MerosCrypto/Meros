#Tests proper handling of Verifications with unsynced Transactions which are beaten by other Transactions.

#Types.
from typing import Dict, IO, Any

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from PythonTests.Classes.Consensus.Consensus import Consensus

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Merit classes.
from PythonTests.Classes.Merit.Merit import Merit

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit, Consensus, and Transactions verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain
from PythonTests.Tests.Consensus.Verify import verifyConsensus
from PythonTests.Tests.Transactions.Verify import verifyTransactions

#JSON standard lib.
import json

def VCompetingTest(
    rpc: RPC
) -> None:
    file: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Competing.json", "r")
    vectors: Dict[str, Any] = json.loads(file.read())
    #Transactions.
    transactions: Transactions = Transactions.fromJSON(vectors["transactions"])
    #Consensus.
    consensus: Consensus = Consensus.fromJSON(
        bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
        vectors["consensus"]
    )
    #Merit.
    merit: Merit = Merit.fromJSON(
        b"MEROS_DEVELOPER_NETWORK",
        60,
        int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
        100,
        transactions,
        consensus,
        vectors["blockchain"]
    )
    file.close()

    #Handshake with the node.
    rpc.meros.connect(254, 254, len(merit.blockchain.blocks))

    sentLast: int = 4
    reqHash: bytes = bytes()
    while True:
        msg: bytes = rpc.meros.recv()

        if MessageType(msg[0]) == MessageType.Syncing:
            rpc.meros.acknowledgeSyncing()

        elif MessageType(msg[0]) == MessageType.GetBlockHash:
            height: int = int.from_bytes(msg[1 : 5], "big")
            if height == 0:
                rpc.meros.blockHash(merit.blockchain.last())
            else:
                if height >= len(merit.blockchain.blocks):
                    raise TestError("Meros asked for a Block Hash we do not have.")

                rpc.meros.blockHash(merit.blockchain.blocks[height].header.hash)

        elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
            reqHash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockHeader(block.header)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Header we do not have.")

        elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
            reqHash = msg[1 : 49]
            for block in merit.blockchain.blocks:
                if block.header.hash == reqHash:
                    rpc.meros.blockBody(block.body)
                    break

                if block.header.hash == merit.blockchain.last():
                    raise TestError("Meros asked for a Block Body we do not have.")

        elif MessageType(msg[0]) == MessageType.ElementRequest:
            rpc.meros.element(
                consensus.holders[msg[1 : 49]][
                    int.from_bytes(msg[49 : 53], "big")
                ]
            )

        elif MessageType(msg[0]) == MessageType.TransactionRequest:
            sentLast -= 1
            rpc.meros.transaction(transactions.txs[msg[1 : 49]])


        elif MessageType(msg[0]) == MessageType.SyncingOver:
            if sentLast == 0:
                break

        else:
            raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, merit.blockchain)

    #Verify the Transactions.
    verifyTransactions(rpc, transactions)

    #Verify the Consensus.
    verifyConsensus(rpc, consensus)

    #Playback their messages.
    rpc.meros.playback()
