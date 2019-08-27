#Syntax Test. Compiles every file to verify the codebase has valid syntax.

#Lib.
import ../src/lib/Errors
import ../src/lib/Util
import ../src/lib/Logger

import ../src/lib/Base32

import ../src/lib/Hash

#Wallet.
import ../src/Wallet/Wallet
import ../src/Wallet/HDWallet
import ../src/Wallet/MinerWallet

#Database.
import ../src/Database/Filesystem/DB/TransactionsDB
import ../src/Database/Filesystem/DB/ConsensusDB
import ../src/Database/Filesystem/DB/MeritDB

import ../src/Database/Transactions/Transactions
import ../src/Database/Consensus/Consensus
import ../src/Database/Merit/Merit

#Network.
import ../src/Network/Serialize/SerializeCommon

import ../src/Network/Serialize/Merit/SerializeRecords
import ../src/Network/Serialize/Merit/SerializeMiners
import ../src/Network/Serialize/Merit/SerializeBlockHeader
import ../src/Network/Serialize/Merit/SerializeBlock

import ../src/Network/Serialize/Merit/ParseRecords
import ../src/Network/Serialize/Merit/ParseMiners
import ../src/Network/Serialize/Merit/ParseBlockHeader
import ../src/Network/Serialize/Merit/ParseBlock

import ../src/Network/Serialize/Consensus/SerializeVerification

import ../src/Network/Serialize/Consensus/ParseVerification

import ../src/Network/Serialize/Transactions/SerializeClaim
import ../src/Network/Serialize/Transactions/SerializeSend
import ../src/Network/Serialize/Transactions/SerializeData

import ../src/Network/Serialize/Transactions/ParseClaim
import ../src/Network/Serialize/Transactions/ParseSend
import ../src/Network/Serialize/Transactions/ParseData

import ../src/Network/Network

#Interfaces.
import ../src/Interfaces/Interfaces

#objects.
import ../src/objects/GlobalFunctionBoxObj
import ../src/objects/ConfigObj
