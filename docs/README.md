# Adding a new page to this site

This file is **not** part of the built site — Zensical excludes `README.md`
automatically since this folder already has its own `index.md`. Safe to keep
here for anyone editing content.

## Steps

1. **Create the file** under `docs/`, with frontmatter:

   ```markdown
   ---
   title: My New Topic
   ---

   # My New Topic

   Content here — headings, admonitions (`!!! note`/`!!! success`/`!!! danger`),
   tables, fenced code blocks, `def_list` definition lists, and Mermaid
   diagrams (` ```mermaid `) all work, same as in jenkins.md/terraform.md.
   ```

2. **Add it to `nav` in `zensical.toml`** (repo root):

   ```toml
   nav = [
     { "Home" = "index.md" },
     ...
     { "My New Topic" = "my-new-topic.md" },
   ]
   ```

   Zensical builds *any* `.md` file under `docs/` whether or not it's in
   `nav` — but without a `nav` entry the page has no sidebar link, so add
   it here to make it discoverable.

3. **(Optional) Link it from `docs/index.md`** too, matching the existing
   topic bullets, so it shows up on the hub page.

## Verify before pushing

```bash
zensical build --clean   # full rebuild; warns on broken internal links
zensical serve           # local preview, live-reloads on save
```

Then `git add`/`commit`/`push` — `.github/workflows/docs.yml` rebuilds and
redeploys automatically on every push to `main`.

## Converting old content

`scripts/html2md.py` was the one-off tool used to convert the original
hand-written HTML site into these Markdown pages. The old site is gone now,
so this is only useful as a reference for its known gotchas (documented in
its own docstring) if a similar conversion is ever needed again.
