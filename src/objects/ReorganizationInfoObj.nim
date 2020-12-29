import stint

import ../lib/Hash
import ../Network/objects/SketchyBlockObj

type ReorganizationInfo* = object
  sharedWork*: StUInt[128]
  existingWork*: StUInt[128]
  existingForkedBlock*: Hash[256]
  altForkedBlock*: Hash[256]
  headers*: seq[SketchyBlockHeader]
