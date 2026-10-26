# A05 — historical verification archive

Baseline containing every removed file: `0af92c40e1355b1a0d8f89a8a3ad7bc0f5ae4b1f` (captured with
`git rev-parse HEAD` before changes). No history was rewritten.

## Restore historical evidence

From a clean checkout with this commit available locally:

```sh
git checkout 0af92c40e1355b1a0d8f89a8a3ad7bc0f5ae4b1f -- docs/design/<path>
```

Replace `<path>` with a file or directory from [archive-manifest.json](archive-manifest.json).
This command updates both the index and working tree; save local changes first.
A shallow clone may need to fetch the baseline commit from its repository remote.
The manifest records every removed path and byte size, the original round/kind
inventory, and targets already missing at baseline. Git history retains the files;
this change reduces current checkouts, not existing Git objects or clone history.

## Retention policy

Retained all Markdown, SHADER-REQUESTS.md, SYSTEMS-REQUESTS.md, JSON/JSONL,
hash lists, scripts, replay sources and configuration/structured data. Retained
existing file targets of local links across repository Markdown, existing inline
code file references, and filenames cited in prose. Kept every MP4 in
`counterphase/recordings/`. Kept the full documented failed-case directories,
including `smooth/attempts/first-sync/`, so rejected captures remain inspectable.

Directory links retain at least one representative file; other contents can be
restored from the baseline. Removed unreferenced frame sequences, duplicate verification runs, attempts,
contact sheets, screenshots, raw logs and tarballs. Explicitly cited logs and
source/benchmark tarballs remain: removing those would discard the reproducibility
or evidence promised by the retained documents. Structured per-frame data also
remains conservatively; this is not a claim of maximum possible compression.
The manifest, rather than filename heuristics, is the authoritative removal list.

`python tools/design_archive.py` inventories/plans without deleting anything;
`--apply` writes a manifest and removes files only when no archive manifest exists.
To reproduce the original plan, run it in a baseline checkout with this script
copied in. Its input is the tracked tree, not ignored build output. Filename
heuristics classify kinds (images under frame/sequence/attempt paths count as
frames); screenshots and contact sheets elsewhere share the screenshot category.

## Packaging audit

Read `installer/aerolith_install/cli.py`: `install_core()` at lines 443–459 copies
only `shell/` (excluding `ai` and `__pycache__`), `installer/aerolith_install/`,
generated launchers and the root README. Optional AI deployment at lines 292–300
copies `ai-bridge/qml/AiModule.qml`, the bridge launcher and `aerolith_ai/`.
`manifest.copy_tree()` at lines 150–169 walks only its supplied source directory.
`packages.py` manages dependency/provider installation, not repository packaging.
`paths.py` supports an externally packaged `/usr/share/aerolith` source.
No tracked PKGBUILD, RPM spec, Makefile, pyproject/setup or desktop release-package
recipe was found. `codex-mcp-bridge/package.json` is private bridge tooling and
only builds TypeScript; it does not package the desktop shell.

Thus the repository installer already excludes `docs/design`; no installer change
was needed. Any future release packager must use explicit runtime source inputs
and exclude `docs/design`. This task does not establish the contents of packages
built outside this repository. No visual or runtime source was changed.

## Measurements

| Scope | Before bytes | After bytes | Before MiB | After MiB |
| --- | ---: | ---: | ---: | ---: |
| docs/design | 766550087 | 249832796 | 731.04 | 238.26 |
| Fresh working tree | 772631143 | 255920807 | 736.84 | 244.07 |

Removed 2982 files totaling 517087279 bytes
before the small added documentation/tooling and link corrections.

File-content sizes include symlink text, exclude `.git`, ignored build products
and directory metadata. Before values are also verified from `git ls-tree -rl HEAD`.
The fresh-tree measurement uses `git archive HEAD | tar -x -C build/A05-checkout`,
then applies these deletions and copies the changed/new files; it is a materialized
checkout equivalent without Git metadata. Disk allocation varies by filesystem.

## Removed per round

| Round | Removed files | Removed bytes | MiB |
| --- | ---: | ---: | ---: |
| (root) | 0 | 0 | 0.00 |
| apps | 0 | 0 | 0.00 |
| complete | 85 | 5708391 | 5.44 |
| counterphase | 616 | 200260368 | 190.98 |
| intensity | 62 | 13280113 | 12.66 |
| limb | 12 | 111590 | 0.11 |
| review | 461 | 34815066 | 33.20 |
| round2 | 12 | 1203951 | 1.15 |
| round3 | 88 | 16215151 | 15.46 |
| schemes | 272 | 108159488 | 103.15 |
| settings | 188 | 32557748 | 31.05 |
| shots | 1 | 86924 | 0.08 |
| smooth | 507 | 9653778 | 9.21 |
| thears-piyti | 319 | 49169784 | 46.89 |
| unhinged | 159 | 38591573 | 36.80 |
| views | 200 | 7273354 | 6.94 |

## Before inventory by round and kind

| Round | Kind | Files | Bytes | MiB |
| --- | --- | ---: | ---: | ---: |
| (root) | documents / other | 9 | 77428 | 0.07 |
| apps | documents / other | 1 | 7483 | 0.01 |
| apps | logs | 5 | 14552 | 0.01 |
| apps | manifests / structured data | 6 | 22002 | 0.02 |
| apps | screenshots | 3 | 863000 | 0.82 |
| apps | scripts / replay sources | 3 | 14351 | 0.01 |
| complete | documents / other | 2 | 13783 | 0.01 |
| complete | logs | 79 | 106969 | 0.10 |
| complete | manifests / structured data | 17 | 203180 | 0.19 |
| complete | screenshots | 70 | 16692437 | 15.92 |
| complete | scripts / replay sources | 13 | 11866 | 0.01 |
| counterphase | documents / other | 18 | 72006 | 0.07 |
| counterphase | frame sequences | 63 | 27244569 | 25.98 |
| counterphase | logs | 391 | 396120 | 0.38 |
| counterphase | manifests / structured data | 615 | 1482145 | 1.41 |
| counterphase | screenshots | 323 | 112898127 | 107.67 |
| counterphase | scripts / replay sources | 14 | 35762 | 0.03 |
| counterphase | videos / motion previews | 14 | 148325483 | 141.45 |
| intensity | documents / other | 1 | 5178 | 0.00 |
| intensity | logs | 22 | 41924 | 0.04 |
| intensity | manifests / structured data | 8 | 14694 | 0.01 |
| intensity | screenshots | 65 | 20480435 | 19.53 |
| intensity | scripts / replay sources | 4 | 6953 | 0.01 |
| limb | documents / other | 2 | 6117 | 0.01 |
| limb | logs | 14 | 51078 | 0.05 |
| limb | manifests / structured data | 6 | 4487 | 0.00 |
| limb | screenshots | 33 | 3453828 | 3.29 |
| review | documents / other | 3 | 40690 | 0.04 |
| review | logs | 196 | 448072 | 0.43 |
| review | manifests / structured data | 20 | 201274 | 0.19 |
| review | screenshots | 430 | 72336171 | 68.99 |
| review | scripts / replay sources | 19 | 27460 | 0.03 |
| round2 | documents / other | 2 | 13193 | 0.01 |
| round2 | manifests / structured data | 7 | 4037 | 0.00 |
| round2 | screenshots | 36 | 3322265 | 3.17 |
| round2 | videos / motion previews | 3 | 2609044 | 2.49 |
| round3 | documents / other | 1 | 2977 | 0.00 |
| round3 | logs | 20 | 69552 | 0.07 |
| round3 | manifests / structured data | 18 | 15162 | 0.01 |
| round3 | screenshots | 105 | 26082411 | 24.87 |
| schemes | documents / other | 10 | 43904 | 0.04 |
| schemes | frame sequences | 16 | 3128356 | 2.98 |
| schemes | logs | 18 | 18515 | 0.02 |
| schemes | manifests / structured data | 90 | 286792 | 0.27 |
| schemes | screenshots | 317 | 120592234 | 115.01 |
| schemes | scripts / replay sources | 17 | 22144 | 0.02 |
| schemes | videos / motion previews | 1 | 140498 | 0.13 |
| settings | documents / other | 5 | 41160 | 0.04 |
| settings | logs | 58 | 39485 | 0.04 |
| settings | manifests / structured data | 16 | 254029 | 0.24 |
| settings | screenshots | 166 | 42780535 | 40.80 |
| settings | scripts / replay sources | 9 | 17962 | 0.02 |
| shots | screenshots | 22 | 1439504 | 1.37 |
| smooth | documents / other | 17 | 69059 | 0.07 |
| smooth | frame sequences | 220 | 3135663 | 2.99 |
| smooth | logs | 86 | 133531 | 0.13 |
| smooth | manifests / structured data | 348 | 2106022 | 2.01 |
| smooth | screenshots | 501 | 18521347 | 17.66 |
| smooth | scripts / replay sources | 24 | 66183 | 0.06 |
| smooth | tarballs | 3 | 1330864 | 1.27 |
| smooth | videos / motion previews | 2 | 4401936 | 4.20 |
| thears-piyti | documents / other | 14 | 54045 | 0.05 |
| thears-piyti | frame sequences | 120 | 41842230 | 39.90 |
| thears-piyti | logs | 161 | 349109 | 0.33 |
| thears-piyti | manifests / structured data | 163 | 685785 | 0.65 |
| thears-piyti | screenshots | 90 | 21445475 | 20.45 |
| thears-piyti | scripts / replay sources | 9 | 29183 | 0.03 |
| thears-piyti | videos / motion previews | 20 | 3298504 | 3.15 |
| unhinged | documents / other | 5 | 16505 | 0.02 |
| unhinged | frame sequences | 88 | 26091639 | 24.88 |
| unhinged | logs | 33 | 150626 | 0.14 |
| unhinged | manifests / structured data | 65 | 72919 | 0.07 |
| unhinged | screenshots | 96 | 27737514 | 26.45 |
| unhinged | scripts / replay sources | 4 | 2410 | 0.00 |
| unhinged | videos / motion previews | 12 | 1148284 | 1.10 |
| views | documents / other | 1 | 6144 | 0.01 |
| views | logs | 13 | 36271 | 0.03 |
| views | manifests / structured data | 3 | 44253 | 0.04 |
| views | screenshots | 190 | 7251203 | 6.92 |

## Verification and limitations

- `python tools/design_archive.py --check-links`: zero broken local Markdown
  file/directory targets across all tracked Markdown plus retained design documents.
  This checks inline/image/reference-style destinations; remote URLs, anchors,
  shell commands and prose paths are not asserted to work.
- Found 29 already-missing local link targets at baseline. Nine Markdown files
  now identify those historical references as unavailable instead of linking to
  nonexistent evidence. This includes A03 logs; its reported results are unchanged.
  The baseline manifest retains all original missing-target identities.
- Retention audit: no Markdown, structured reproducibility input, directly linked
  existing file, Counterphase recording or documented first-sync failure file removed.
- `git diff --check`: passed. No shell/theme/installer/test file changed.
- Runtime tests were not rerun: changes affect historical documentation/assets only.
- One review of the other engineer's installer copy boundary (`install_core`,
  `plan_ai.install_module` copy sites, `copy_tree`) found no actionable inclusion of design assets.
  This is a bounded source review, not a re-review of the entire systems implementation.
- Historical scripts/manifests can name pruned captures in data or commands. Restore
  those inputs from the baseline to replay a complete historical run. Markdown link
  validity does not prove runtime reproducibility or visual quality.
