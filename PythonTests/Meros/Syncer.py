#Types.
from typing import Dict, List, Tuple, Union, Any

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Consensus classes.
from PythonTests.Classes.Consensus.Element import Element
from PythonTests.Classes.Consensus.Verification import Verification
from PythonTests.Classes.Consensus.Consensus import Consensus

#Transactions class.
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC

#Merit, Consensus, and Transactions verifiers.
from PythonTests.Tests.Merit.Verify import verifyBlockchain
from PythonTests.Tests.Consensus.Verify import verifyConsensus
from PythonTests.Tests.Transactions.Verify import verifyTransactions

#BLS lib.
import blspy

#pylint: disable=too-many-instance-attributes
class Syncer():
    def __init__(
        self,
        rpc: RPC,
        blockchain: Blockchain,
        consensus: Union[Consensus, None] = None,
        transactions: Union[Transactions, None] = None,
        settings: Dict[str, Any] = {}
    ) -> None:
        #RPC.
        self.rpc: RPC = rpc

        #DBs/Settings.
        self.blockchain: Blockchain = blockchain
        if consensus is not None:
            self.consensus: Consensus = consensus
        if transactions is not None:
            self.transactions: Transactions = transactions
        self.settings: Dict[str, Any] = dict(settings)

        #Provide default settings.
        if "height" not in self.settings:
            self.settings["height"] = len(self.blockchain.blocks) - 1
        if "playback" not in self.settings:
            self.settings["playback"] = True

        #Dict of available Merit Holders to their tips.
        self.tips: Dict[bytes, int] = {}
        #Same as above, except it's never deleted from.
        self.allTips: Dict[bytes, int] = {}
        #Dict of the tail block's tips.
        self.tailTips: Dict[bytes, int] = {}

        #Dict of mentioned Transactions.
        self.txs: Dict[bytes, bool] = {}
        #Dict of synced Transactions.
        self.synced: Dict[bytes, bool] = {}

    #Update TXs from a holder and class data.
    def updateTXs(
        self,
        holder: bytes,
        tips: Dict[bytes, int]
    ) -> None:
        #If the holder doesn't have an entry, provide one.
        if holder not in self.allTips:
            self.allTips[holder] = -1

        #Iterate over every new Element.
        for e in range(self.allTips[holder] + 1, tips[holder] + 1):
            elem: Element = self.consensus.holders[holder][e]

            #If it was a Verification, track the mentionmd transaction.
            if isinstance(elem, Verification):
                if Verification.fromElement(elem).hash not in self.synced:
                    self.txs[Verification.fromElement(elem).hash] = True

    #Update tips from records.
    def updateTips(
        self,
        nonce: int,
        records: List[Tuple[blspy.PublicKey, int, bytes]]
    ) -> bool:
        #If this is the tail block, save them to a different dict.
        if nonce == self.settings["height"]:
            for record in records:
                self.tailTips[record[0].serialize()] = record[1]
            return False

        if not records:
            return False

        for record in records:
            holder: bytes = record[0].serialize()

            #Update the deletable tips.
            self.tips[holder] = record[1]

            #Update the TXs.
            self.updateTXs(holder, self.tips)

            #Update the non-deletable tips.
            self.allTips[holder] = record[1]
        return True

    #Load the tail tips.
    def loadTailTips(
        self
    ) -> None:
        #Iterate over every holder.
        for holder in self.tailTips:
            #Update the Transactions.
            self.updateTXs(holder, self.tailTips)

        #Set tips to tailTips.
        self.tips = self.tailTips

    #Sync the DB and verify it.
    def sync(
        self
    ) -> None:
        #Handshake with the node.
        self.rpc.meros.connect(254, 254, self.settings["height"] + 1)

        #Handle sync requests.
        reqHash: bytes = bytes()
        lastBlock: int = 0
        hadTips: bool = False
        while True:
            msg: bytes = self.rpc.meros.recv()

            if MessageType(msg[0]) == MessageType.Syncing:
                self.rpc.meros.acknowledgeSyncing()

            elif MessageType(msg[0]) == MessageType.GetBlockHash:
                height: int = int.from_bytes(msg[1 : 5], "big")

                if height == 0:
                    self.rpc.meros.blockHash(self.blockchain.blocks[self.settings["height"]].header.hash)
                else:
                    if height > self.settings["height"]:
                        raise TestError("Meros asked for a Block Hash we don't have.")
                    self.rpc.meros.blockHash(self.blockchain.blocks[height].header.hash)

            elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
                reqHash = msg[1 : 49]

                for block in self.blockchain.blocks:
                    if block.header.hash == reqHash:
                        self.rpc.meros.blockHeader(block.header)
                        break

                    if block.header.hash == self.blockchain.blocks[self.settings["height"]].header.hash:
                        raise TestError("Meros asked for a Block Header we don't have.")

            elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
                reqHash = msg[1 : 49]

                if self.tips != {}:
                    raise TestError("Meros requested a new BlockBody despite not finishing syncing the existing tips.")

                for block in self.blockchain.blocks:
                    if block.header.hash == reqHash:
                        #Update the tips.
                        hadTips = self.updateTips(block.header.nonce, block.body.records)

                        #Send the BlockBody.
                        self.rpc.meros.blockBody(block.body)
                        lastBlock = block.header.nonce + 1

                        #We check to load the tail tips AFTER an ElementRequest,
                        #Therefore, if there aren't any tips before in in the second to last block, we won't load them.
                        #This handles that case.
                        if (
                            (not hadTips) and
                            (lastBlock == self.settings["height"])
                        ):
                            self.loadTailTips()
                        break

                    if block.header.hash == self.blockchain.blocks[self.settings["height"]].header.hash:
                        raise TestError("Meros asked for a Block Body we don't have.")

            elif MessageType(msg[0]) == MessageType.ElementRequest:
                holder: bytes = msg[1 : 49]
                nonce: int = int.from_bytes(msg[49 : 53], "big")

                if self.consensus is None:
                    raise TestError("Meros asked for an Element when we have none.")

                if holder not in self.consensus.holders:
                    raise TestError("Meros asked for an Element from a holder we don't have.")

                if nonce >= len(self.consensus.holders[holder]):
                    raise TestError("Meros asked for an Element we don't have.")

                if holder not in self.tips:
                    raise TestError("Meros asked for an Element from a holder we haven't mentioned/they already fully synced.")

                self.rpc.meros.element(self.consensus.holders[holder][nonce])

                if nonce == self.tips[holder]:
                    del self.tips[holder]

                #If this is the Block before the tail, and tips is empty, correct the tips/TXs.
                if (
                    (lastBlock == self.settings["height"]) and
                    (self.tips == {})
                ):
                    self.loadTailTips()

            elif MessageType(msg[0]) == MessageType.TransactionRequest:
                reqHash = msg[1 : 49]

                if self.transactions is None:
                    raise TestError("Meros asked for a Transaction when we have none.")

                if reqHash not in self.transactions.txs:
                    raise TestError("Meros asked for a Transaction we don't have.")

                if reqHash not in self.txs:
                    raise TestError("Meros asked for a Transaction we haven't mentioned/they already synced.")

                self.rpc.meros.transaction(self.transactions.txs[reqHash])
                self.synced[reqHash] = True
                del self.txs[reqHash]

            elif MessageType(msg[0]) == MessageType.SyncingOver:
                #Break out of the foor loop if the sync finished.
                #This means we sent every Block, every Element, every Transaction...
                if (
                    (lastBlock == self.settings["height"]) and
                    (self.tips == {}) and
                    (self.txs == {})
                ):
                    #Make sure we handled the tail tips.
                    handled: bool = True
                    for holder in self.tailTips:
                        if holder not in self.allTips:
                            handled = False
                            break

                        if self.allTips[holder] != self.tailTips[holder]:
                            handled = False
                            break

                    if handled:
                        break

            else:
                raise TestError("Unexpected message sent: " + msg.hex().upper())

        #Verify the Blockchain.
        verifyBlockchain(self.rpc, self.blockchain)

        #Verify the Consensus.
        try:
            verifyConsensus(self.rpc, self.consensus)
        except AttributeError:
            pass

        #Verify the Transactions.
        try:
            verifyTransactions(self.rpc, self.transactions)
        except AttributeError:
            pass

        if self.settings["playback"]:
            #Playback their messages.
            self.rpc.meros.playback()
