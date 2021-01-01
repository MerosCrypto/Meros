import stint

import ../lib/Hash
import ../Database/Merit/objects/BlockHeaderObj

type ReorganizationInfo* = object
  sharedWork*: StUInt[128]
  existingWork*: StUInt[128]
  existingForkedBlock*: Hash[256]
  altForkedBlock*: Hash[256]
  headers*: seq[BlockHeader]
