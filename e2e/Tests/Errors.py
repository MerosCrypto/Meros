#Used when the node fails.
class NodeError(
  Exception
):
  pass

#Used when a test succeeds yet needs to cut execution short.
class SuccessError(
  Exception
):
  pass

#Used when a test fails.
class TestError(
  Exception
):
  message: str
