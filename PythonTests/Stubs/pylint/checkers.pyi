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
        line: int = 0,
        node: Any = None,
        args: Any = None,
        confidence: Any = None,
        col_offset: Any = None
    ) -> None:
        ...
