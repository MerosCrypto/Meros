from typing import Any

from pylint.lint import PyLinter

class BaseChecker:
  def __init__(
    self,
    linter: PyLinter
  ) -> None:
    ...

  def add_message(
    self,
    msgid: str,
    line: int = ...,
    node: Any = ...,
    args: Any = ...,
    confidence: Any = ...,
    col_offset: Any = ...
  ) -> None:
    ...
