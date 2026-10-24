# UI-016 motion review

This is a source review of the provisional implementation; runtime marker evidence and final required scenarios are recorded separately. No production edits were made by this verification subtask.

ChordSlot uses separate transform/opacity Animator Behaviors with no explicit `from`. Qt's [Behavior implementation](https://github.com/qt/qtdeclarative/blob/dev/src/quick/util/qquickbehavior.cpp) stops a running Animator, synchronizes its rendered value to the item, and reads that current value before constructing the replacement transition. This supports retargeting a live entry to exit without first applying the settled pose. [Qt's Animator documentation](https://doc.qt.io/qt-6/qml-qtquick-animator.html) also explains why QML property samples during an Animator are insufficient evidence of actual intermediate pixels. The deferred `presented` activation's event ordering still requires rendered-marker verification; source inspection alone does not establish that first entry frame.

Counterphase snapshots home, tip and duration at each finite stroke's start. A beat ignores an already-running stroke, and workspace/direction changes do not restart one. Reduced/off and lowEffects suppression explicitly return marks home; that safety reset is distinct from ordinary interaction retargeting. The low-frequency Timer controls stroke cadence, not per-frame motion.

Shear focus groups omit a fixed starting displacement, so a subsequent focus event requests a new excursion from the synchronized current value. Reduced/off and loss of exposure cancel the focus job. The focus-flash group likewise has no explicit fixed starting opacity. A source review cannot quantify rendered focus continuity; no such measurement is claimed here.

The OSD keeps a NumberAnimation for opacity because its host-facing `presenting` and `settled()` contract needs observable fade completion. Its new callback is connected to animation running-state changes rather than every opacity update; the deferred completion rechecks `exitPending`, `presentationOpen` and opacity. Reopening before the callback therefore invalidates an obsolete exit. Disabling motion explicitly completes the fade and queues a final check. Transform travel stops for reduced/off; a regular reduced opacity fade remains time-based.

The only actionable protected-host finding is retained in `SYSTEMS-REVIEW.md`: Deck's existing exit Timer snapshots the old lifetime when motion/lowEffects is disabled mid-exit. Root records the request for Claude because this task forbids modifying the host.
