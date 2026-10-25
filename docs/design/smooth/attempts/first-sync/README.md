# Native Animator first-sync attempt (superseded)

These diagnostic snapshots show the first native-Animator implementation before its render-state initialization correction. They are retained as the failed attempt, not final AFTER evidence. The magenta 10 px fiducial is attached only in copied ChordSlot.qml files.

Full-frame captures in `full-position/` confirmed the bay entering from x≈0 before settling at x710, rather than its intended x744 entry pose. Cropped captures missed that out-of-bounds travel; their missing marker was not merely a crop artifact. The nominal 35/70 ms timer close requests were delayed by synchronous software rendering and screenshot load, so logged actual open/close times must be used.

Container runtime sessions completed successfully; initial host position JSON rewrites failed permissions because those files belonged to the container user. The diagnostic postprocessor was corrected to write a temporary file then atomically replace the output, preserving raw captures. These samples do not establish uninterrupted or 144 fps motion.
