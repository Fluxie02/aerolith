"""AEROLITH AI Bridge.

An optional, separately installed component that lets the AEROLITH shell
send an explicit, user-typed request to a configured AI provider (Claude
Code, Codex, or a custom adapter) and get back a reply plus *proposed*
actions. Proposals are never executed here: the shell validates them against
its command registry and the user approves each one.

The bridge uses only the Python standard library. It never reads, copies or
prints provider credentials; providers authenticate themselves with their
own mechanisms.
"""

__version__ = "0.1.0"
PROTOCOL_VERSION = 1
