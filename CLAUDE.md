# Project instructions

## Site architecture

This site is built with [Zensical](https://zensical.org/) (a Markdown-based static site generator). Content lives in `docs/*.md`, config in `zensical.toml`, and `.github/workflows/docs.yml` builds and deploys it to GitHub Pages automatically on every push to `main`.

- **To add or edit a page**: see `docs/README.md` (not built into the site — it's maintainer/agent-facing documentation, excluded automatically by Zensical since `docs/` already has its own `index.md`).
- **Local build/preview**: `pip install -r requirements.txt`, then `zensical build --clean` (full rebuild, exits non-zero / warns on broken internal links) or `zensical serve` (local preview server with live-reload).
- The original site was a set of hand-written HTML files (`index.html`, `week2.html`–`week5.html`, plus `styles.css`/`script.js`/`search-index.js`). It was retired in commit `7a56b65` and migrated into the current `docs/*.md` structure — those files are gone from the working tree but still recoverable from git history if ever needed: `git show 7a56b65~1:<filename>`. `scripts/html2md.py` was the migration tool; it's no longer needed for routine work, but its logic (and the gotchas below) is directly relevant if a similar HTML→Markdown migration is ever needed again, or if new content is hand-authored with raw embedded HTML.

## This repo is public — never add real security-sensitive values

Do not write real AWS account IDs, real resource IDs (VPC/subnet/security-group/AMI/instance/route-table/IGW/NAT/launch-template IDs, etc.), real public IP addresses, or any other credential-like or account-identifying values into any tracked file (this includes every file under `docs/`, and `IaC/`/`jenkins/` too unless the user has explicitly said otherwise for a specific file).

This applies **even when the user pastes terminal output, CLI results, or another AI's response that contains real values** — extract the teaching content, but replace any real identifier with an obviously fake placeholder before writing it to a file. Good placeholder conventions already used in this repo:

- AWS account ID → `111122223333` (AWS's own documentation placeholder)
- Resource IDs → keep the real prefix/shape but replace the hex suffix, e.g. `vpc-0123456789abcdef0`, `subnet-0aaa1111aaaa11111`, `ami-0bbbbbbbbbbbbbbbb`
- Public IP addresses → `203.0.113.10` (IANA TEST-NET-3 documentation range)
- When the same real ID appears in multiple places, map it to the *same* fake value everywhere so cross-references and comparison tables still read correctly — don't just replace every ID with one generic value.

If the user pastes something containing real account/resource IDs, either scrub it silently before adding it to a file, or flag it and ask — never add it verbatim on the assumption that "they pasted it, so it's fine." Real personal names/employer/client details in planning documents get the same treatment: ask before including them in anything public-facing (this has come up before — see git history around the root `README.md`).

Before considering any content addition done, a quick `grep -rnE '\b[0-9]{12}\b'` across `docs/` and a scan for resource-ID-shaped strings (`ami-`, `vpc-`, `subnet-`, `sg-`, `i-`, `igw-`, `rtb-`, `nat-`, `lt-` followed by hex) is a good final check.

## Known Zensical/Markdown gotchas

These are real, confirmed bugs (each verified with a minimal reproduction, not assumed) in Python-Markdown's HTML/table handling. They apply to **any** future content — hand-authored or migrated — not just the original migration.

**Embedding raw HTML (especially a hand-drawn `<svg>` diagram) directly in a `.md` file** — three separate things will silently corrupt it, each confirmed independently:

1. A `<style>` tag anywhere inside the block causes Python-Markdown to drop *every child element* of the block, leaving just the empty outer tag.
2. A **blank line** anywhere inside the block ends it early — everything after the blank line falls back to normal Markdown parsing and gets mangled (this is true even with no `<style>` tag).
3. An **HTML comment** (`<!-- ... -->`) anywhere inside the block does the same thing as a blank line — silently truncates everything after it.

The fix for all three: no `<style>` tag (convert CSS classes to inline `style="..."` attributes on each element instead), no blank lines anywhere between the opening and closing tag, no comments. See `render_svg()` in `scripts/html2md.py` for a working reference implementation — it does all three fixups programmatically and is safe to reuse or adapt.

**Writing a `def_list` (Term\n:   Definition) block** — if two term/definition pairs are placed back-to-back with **no blank line between them**, Python-Markdown nests the second pair *inside* the first definition instead of treating them as siblings. Always put a blank line between each term/definition pair, even though a single pair's own term/definition line don't need one between them.

**Writing a Markdown table** — a literal `|` character inside a cell's text (e.g. an enum list like `USD | GB | HOURS`) is parsed as an extra column separator and silently corrupts/drops the rest of that row. Escape it as `\|`.

## Verifying content changes

Don't eyeball a content change and call it done — verify:

- `zensical build --clean` exits with "No issues found." Any "Warning: anchor does not exist" means a broken internal link — fix it, don't ignore it.
- If migrating or substantially rewriting content from another source: compare `dt`/`dd`, `<table>`, and admonition (`.fact`/`.admonition`) counts between the source and the *built* HTML output — not just the Markdown source, since a structural bug (like the three above) can look fine in the `.md` file and still render broken. Total visible text length should be within ~1% of the source; anything further off is worth investigating before moving on (a large table with literal `|` characters, a `def_list` nested wrong, etc. — several real examples of exactly this happened during the original migration).

## Internal cross-references between pages

Zensical auto-generates heading anchors by slugifying the heading text: lowercase, strip everything that isn't a word character/whitespace/hyphen, collapse whitespace to a single hyphen. E.g. `## 3.7 IAM — Identity and Access Management` becomes `#37-iam-identity-and-access-management` (the number's dot and the em-dash both just vanish). To link to a heading on a *different* page, use `otherpage.md#the-computed-slug` in the Markdown source — Zensical rewrites this to the correct final URL at build time. Don't guess the slug; either build once and check the generated `id=` attribute, or replicate the exact slugify algorithm (`lowercase; re.sub(r"[^\w\s-]", ""); re.sub(r"\s+", "-", text.strip())`).
