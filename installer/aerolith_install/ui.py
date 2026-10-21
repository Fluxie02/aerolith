"""Plain, keyboard-only terminal prompts. No curses, no dependencies.

Non-interactive runs (--yes / no TTY) never guess a consequential answer:
questions without a safe default raise NeedAnswer so the caller can tell the
user which flag to pass.
"""

from __future__ import annotations

import os
import sys


class NeedAnswer(RuntimeError):
    """A question needs an explicit answer that was not given."""


class Ui:
    def __init__(self, assume_yes: bool = False, interactive: bool | None = None, color: bool | None = None):
        self.assume_yes = assume_yes
        self.interactive = sys.stdin.isatty() if interactive is None else interactive
        self.color = (sys.stdout.isatty() and os.environ.get("NO_COLOR") is None) if color is None else color

    def _c(self, code: str, s: str) -> str:
        return f"\033[{code}m{s}\033[0m" if self.color else s

    def title(self, s: str) -> None:
        print()
        print(self._c("1;36", s.upper()))
        print(self._c("2", "─" * min(72, max(len(s), 24))))

    def say(self, s: str = "") -> None:
        print(s)

    def ok(self, s: str) -> None:
        print(self._c("36", "  ok    ") + s)

    def warn(self, s: str) -> None:
        print(self._c("33", "  warn  ") + s)

    def fail(self, s: str) -> None:
        print(self._c("31", "  fail  ") + s)

    def info(self, s: str) -> None:
        print(self._c("2", "  info  ") + s)

    def code(self, s: str) -> None:
        for line in s.rstrip("\n").splitlines():
            print(self._c("2", "    │ ") + line)

    def confirm(self, question: str, default: bool | None = False) -> bool:
        """Yes/no. With --yes, returns True. Without a TTY and without --yes,
        returns the default if there is one, else raises NeedAnswer."""
        if self.assume_yes:
            return True
        if not self.interactive:
            if default is None:
                raise NeedAnswer(question)
            return default
        hint = "[y/n]" if default is None else ("[Y/n]" if default else "[y/N]")
        while True:
            try:
                ans = input(f"{question} {hint} ").strip().lower()
            except EOFError:
                raise NeedAnswer(question) from None
            if ans in ("y", "yes"):
                return True
            if ans in ("n", "no"):
                return False
            if ans == "" and default is not None:
                return default

    def choose(self, question: str, options: list[tuple[str, str, str]], given: str | None = None) -> str:
        """Pick one of options [(key, label, explanation)]. There is no default:
        an empty answer asks again. `given` comes from a command-line flag."""
        keys = [o[0] for o in options]
        if given is not None:
            if given not in keys:
                raise NeedAnswer(f"{question}: '{given}' is not one of {', '.join(keys)}")
            return given
        if not self.interactive:
            raise NeedAnswer(question)
        print(question)
        for i, (_key, label, expl) in enumerate(options, 1):
            print(f"  {self._c('1', str(i))}. {label}")
            for line in expl.splitlines():
                print(self._c("2", "       " + line))
        while True:
            try:
                ans = input(f"Choose 1-{len(options)}: ").strip().lower()
            except EOFError:
                raise NeedAnswer(question) from None
            if ans.isdigit() and 1 <= int(ans) <= len(options):
                return options[int(ans) - 1][0]
            if ans in keys:
                return ans
            print("Please choose one of the listed options.")

    def ask(self, question: str, given: str | None = None, validate=None) -> str:
        if given is not None:
            err = validate(given) if validate else None
            if err:
                raise NeedAnswer(f"{question}: {err}")
            return given
        if not self.interactive:
            raise NeedAnswer(question)
        while True:
            try:
                ans = input(f"{question} ").strip()
            except EOFError:
                raise NeedAnswer(question) from None
            err = validate(ans) if validate else None
            if not err:
                return ans
            print(f"  {err}")
