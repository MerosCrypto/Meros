from pylint.checkers import BaseChecker

class PyLinter():
    def register_checker(
        self,
        checker: BaseChecker
    ) -> None:
        ...
