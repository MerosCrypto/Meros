#Syntax Test. Compiles every file to verify the codebase has valid syntax.

#Disable the UnusedImport warning for this file.
{.used.}

#Disabling the warnings for the below files should be possible via:
#{.push warning[UnusedImport]: off.}
#This didn't work when tested.

#Lib.
import ../src/lib/Errors
import ../src/lib/Util
import ../src/lib/Hash
import ../src/lib/Merkle
import ../src/lib/Sketcher
import ../src/lib/Logger

#Wallet.
import ../src/Wallet/Wallet
import ../src/Wallet/MinerWallet

#Database.
import ../src/Database/Filesystem/DB/DB
import ../src/Database/Transactions/Transactions
import ../src/Database/Consensus/Consensus
import ../src/Database/Merit/Merit

#Network.
import ../src/Network/Serialize/SerializeCommon

import ../src/Network/Serialize/Merit/SerializeBlockHeader
import ../src/Network/Serialize/Merit/SerializeBlockBody
import ../src/Network/Serialize/Merit/SerializeBlock

import ../src/Network/Serialize/Merit/ParseBlockHeader
import ../src/Network/Serialize/Merit/ParseBlockBody
import ../src/Network/Serialize/Merit/ParseBlock

import ../src/Network/Serialize/Consensus/SerializeElement
import ../src/Network/Serialize/Consensus/SerializeVerification
import ../src/Network/Serialize/Consensus/SerializeVerificationPacket
import ../src/Network/Serialize/Consensus/SerializeMeritRemoval

import ../src/Network/Serialize/Consensus/ParseVerification
import ../src/Network/Serialize/Consensus/ParseVerificationPacket
import ../src/Network/Serialize/Consensus/ParseMeritRemoval
import ../src/Network/Serialize/Consensus/ParseElement
import ../src/Network/Serialize/Consensus/ParseBlockElement

import ../src/Network/Serialize/Transactions/SerializeTransaction
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
