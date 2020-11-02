from typing import Optional

#Exception with a message field.
class MessageException(
  Exception
):
  def __init__(
    self,
    msg: Optional[str] = None
  ) -> None:
    self.message: str = ""
    if msg:
      self.message = msg
      Exception.__init__(self, msg)
    else:
      Exception.__init__(self)

#Used when the node fails.
class NodeError(
  MessageException
):
  pass

#Used when a test succeeds yet needs to cut execution short.
class SuccessError(
  MessageException
):
  pass

#Used when a test fails.
class TestError(
  MessageException
):
  pass
