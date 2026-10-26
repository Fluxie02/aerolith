"""AEROLITH installer and maintenance tool (`aerolith`).

Standard library only. Installs AEROLITH for the current user, records every
file it creates in an ownership manifest, and removes exactly those files
again. It never edits unrelated configuration silently: the only change to a
file AEROLITH does not own is one marker-delimited include block in the
Hyprland config, made after showing it and taking a backup.
"""

__version__ = "0.1.0a1"
