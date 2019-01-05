discard """
    This file's name is a bit of a misnomer. This file does NOT handle Verifications.

    Instead, it serializes a seq[Index] (the `verifications` field in a Block object).
    This code also adds Merkles so we can see what Verifier has conflicting Verifications (if one does).
    The Aggregate Signature is enough to check validity in general, but it's not optimal for getting started on correcting the error.
"""
