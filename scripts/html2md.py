#!/usr/bin/env python3
"""Convert one <details class="day"> block from the old site's HTML into
Zensical-flavored Markdown. Migration tool used while moving content from
index.html/week2-5.html into docs/*.md -- retire it once that's done.

Usage: python3 scripts/html2md.py <source.html> <day-id> > docs/<topic>.md

After conversion, always:
  1. Fix cross-page references by hand (e.g. "week4.html 18.10" ->
     "terraform.html 18.10") -- see the replace block used for jenkins.md.
  2. Copy any referenced images into docs/images/<topic>/ and fix their
     paths in the generated Markdown.
  3. Verify: dt/dd counts, table counts, and admonition counts should match
     the source exactly; total text length should be within ~1% of source
     (a python-markdown def_list bug nests dt/dd pairs with no blank line
     between them -- already fixed here, but re-check after edits).
"""
import sys
import re
from bs4 import BeautifulSoup, NavigableString, Tag

FACT_MAP = {
    "fact-good": "success",
    "fact-fail": "danger",
    "fact-note": "note",
}

# Which old source file+day each day's content moves into. Keep in sync with
# the migration plan -- used to resolve real <a href="#dX-Y"> links (not
# every "(20.3)"-style cross-reference is a real hyperlink, but some are).
DAY_TO_TOPIC = {
    ("index.html", 1): "principles.md", ("index.html", 2): "principles.md",
    ("index.html", 3): "iam-accounts.md",
    ("index.html", 4): "networking.md",
    ("week2.html", 5): "compute.md",
    ("week2.html", 6): "load-balancing-dns.md",
    ("week2.html", 7): "databases.md",
    ("week2.html", 8): "storage-observability.md",
    ("week2.html", 9): "compute.md",
    ("week3.html", 10): "containers.md", ("week3.html", 11): "containers.md",
    ("week3.html", 12): "containers.md", ("week3.html", 13): "containers.md",
    ("week3.html", 14): "containers.md",
    ("week4.html", 15): "terraform.md", ("week4.html", 16): "terraform.md",
    ("week4.html", 17): "terraform.md", ("week4.html", 18): "terraform.md",
    ("week4.html", 19): "terraform.md",
    ("week5.html", 20): "jenkins.md",
    ("week5.html", 21): "cicd-delivery.md", ("week5.html", 22): "cicd-delivery.md",
}

SOURCE_FILES = ["index.html", "week2.html", "week3.html", "week4.html", "week5.html"]

# id -> (heading_text, topic_md_file), populated by build_anchor_map() once
# per process. Used to resolve <a href="#dX-Y"> into the right slug, possibly
# in a different .md file than the one currently being converted.
ANCHOR_MAP = {}
CURRENT_TOPIC = None


def slugify(text):
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s+", "-", text.strip())


def build_anchor_map(base_dir="."):
    import os
    for fname in SOURCE_FILES:
        path = os.path.join(base_dir, fname)
        try:
            soup = BeautifulSoup(open(path), "html.parser")
        except FileNotFoundError:
            continue
        for el in soup.find_all(id=re.compile(r"^d\d+")):
            m = re.match(r"^d(\d+)", el["id"])
            day_num = int(m.group(1))
            topic = DAY_TO_TOPIC.get((fname, day_num))
            if not topic:
                continue
            heading = el.find(["h2", "h3"])
            if heading is None and el.name == "details" and "strategy" in (el.get("class") or []):
                summary = el.find("summary")
                if summary:
                    chev = summary.find("span", class_="chev-sm")
                    text = summary.get_text() if not chev else summary.get_text().replace(chev.get_text(), "")
                    ANCHOR_MAP[el["id"]] = (text.strip(), topic)
                continue
            if heading is not None:
                # The rendered Markdown heading is "{sub-num} {title}" (see
                # convert_day) -- match that exactly, since Zensical slugs
                # the *rendered* heading text, not just the <h3> title.
                summary = el.find("summary", recursive=False)
                subnum = summary.find("span", class_=re.compile("sub-num|day-badge")) if summary else None
                num = subnum.get_text().strip() if subnum else ""
                full_text = f"{num} {heading.get_text().strip()}" if num else heading.get_text().strip()
                ANCHOR_MAP[el["id"]] = (full_text, topic)


def inline(el):
    """Render inline content (mixed text + <code>/<strong>/<em>/<a>) as Markdown."""
    if isinstance(el, NavigableString):
        return str(el)
    if el.name == "code":
        return f"`{el.get_text()}`"
    if el.name in ("strong", "b"):
        return f"**{''.join(inline(c) for c in el.children)}**"
    if el.name in ("em", "i"):
        return f"*{''.join(inline(c) for c in el.children)}*"
    if el.name == "a":
        href = el.get("href", "")
        text = "".join(inline(c) for c in el.children)
        if href.startswith("#") and href[1:] in ANCHOR_MAP:
            heading_text, target_topic = ANCHOR_MAP[href[1:]]
            slug = slugify(heading_text)
            href = f"#{slug}" if target_topic == CURRENT_TOPIC else f"{target_topic}#{slug}"
        return f"[{text}]({href})"
    if el.name == "br":
        return "  \n"
    # unknown inline-ish tag: just recurse
    return "".join(inline(c) for c in el.children)


def inline_all(el):
    return "".join(inline(c) for c in el.children).strip()


def indent_block(text, prefix="    "):
    return "\n".join((prefix + line if line.strip() else "") for line in text.split("\n"))


def render_table(table):
    # A literal "|" in cell text (e.g. an enum list "USD | GB | HOURS") must
    # be escaped -- otherwise Markdown's table parser reads it as an extra
    # column separator and silently corrupts/drops the rest of that row.
    def cell(c):
        return inline_all(c).replace("\n", " ").replace("|", "\\|")

    rows = table.find_all("tr")
    out = []
    head = rows[0].find_all(["th", "td"])
    out.append("| " + " | ".join(cell(c) for c in head) + " |")
    out.append("|" + "|".join(["---"] * len(head)) + "|")
    for r in rows[1:]:
        cells = r.find_all(["td", "th"])
        out.append("| " + " | ".join(cell(c) for c in cells) + " |")
    return "\n".join(out)


def render_dl(dl):
    # A blank line is required between each dt/dd pair -- without one,
    # Python-Markdown's def_list nests the next dt/dd *inside* the previous
    # dd instead of treating it as a sibling term.
    pairs = []
    pair = []
    for child in dl.find_all(["dt", "dd"], recursive=False):
        if child.name == "dt":
            pair.append(inline_all(child))
        else:
            pair.append(f":   {inline_all(child)}")
            pairs.append("\n".join(pair))
            pair = []
    return "\n\n".join(pairs)


def render_fact(div):
    # A fact box's body isn't always a single <p> -- it can be a <pre
    # class="diagram">, multiple paragraphs, or other block content. Render
    # everything except the <span class="tag"> title via the general
    # block-level dispatcher instead of assuming <p> is the only shape.
    classes = div.get("class", [])
    kind = next((FACT_MAP[c] for c in classes if c in FACT_MAP), "note")
    tag = div.find("span", class_="tag")
    title = inline_all(tag) if tag else ""
    body_soup = BeautifulSoup(f"<div>{div}</div>", "html.parser").div.div
    if tag is not None:
        t = body_soup.find("span", class_="tag")
        if t:
            t.decompose()
    chunks = block_to_md(body_soup, heading_level=4)
    body = "\n\n".join(indent_block(c) for c in chunks)
    header = f'!!! {kind} "{title}"' if title else f"!!! {kind}"
    return header + "\n\n" + body


def render_pre(pre):
    lang = pre.get("data-lang", "")
    code = pre.get_text()
    if code.endswith("\n"):
        code = code[:-1]
    return f"``` {lang}\n{code}\n```" if lang else f"```\n{code}\n```"


def render_list(el, ordered):
    out = []
    marker = None
    for i, li in enumerate(el.find_all("li", recursive=False), 1):
        m = f"{i}." if ordered else "-"
        out.append(f"{m} {inline_all(li)}")
    return "\n".join(out)


def render_figure(fig):
    cap = fig.find("figcaption")
    mermaid = fig.find("div", class_="mermaid")
    if mermaid:
        # mermaid's own syntax uses literal "<br/>" inside node labels for line
        # breaks -- get_text() would silently drop it, so serialize by hand.
        parts = []
        for c in mermaid.children:
            parts.append(str(c) if isinstance(c, NavigableString) else "<br/>")
        src = "".join(parts).strip("\n")
        out = f"``` mermaid\n{src}\n```"
    else:
        img = fig.find("img")
        src = img.get("src", "") if img else ""
        alt = img.get("alt", "") if img else ""
        out = f"![{alt}]({src})"
    if cap:
        out += f"\n\n*{inline_all(cap)}*"
    return out


def render_quiz(quiz, heading_level):
    """A .quiz div is an interactive click-to-reveal JS widget -- no Zensical
    equivalent, so render it as a static question/options list with the full
    answer + explanation preserved in a collapsible admonition instead."""
    chunks = []
    title_tag = quiz.find("h4")
    badge = quiz.find("span", class_="tag")
    if title_tag:
        prefix = f"{inline_all(badge)}: " if badge else ""
        chunks.append(f"{'#' * (heading_level + 1)} {prefix}{inline_all(title_tag)}")
    for q in quiz.find_all("div", class_="quiz-q"):
        prompt = q.find("div", class_="quiz-prompt")
        qnum = prompt.find("span", class_="q-num") if prompt else None
        qnum_text = inline_all(qnum) if qnum else ""
        if qnum:
            qnum.extract()
        prompt_text = inline_all(prompt) if prompt else ""
        chunks.append(f"**{qnum_text}.** {prompt_text}")

        opts_lines = []
        for opt in q.select(".quiz-opts .quiz-opt"):
            letter = opt.find("span", class_="letter")
            text = opt.find("span", class_="opt-text")
            opts_lines.append(f"- **{inline_all(letter)}.** {inline_all(text)}")
        chunks.append("\n".join(opts_lines))

        exp = q.find("div", class_="exp-box")
        if exp:
            label = exp.find("div", class_="exp-label")
            answer_title = inline_all(label) if label else "Answer"
            body_parts = []
            for p in exp.find_all("p", recursive=False):
                body_parts.append(inline_all(p))
            breakdown = exp.find("div", class_="opt-breakdown")
            if breakdown:
                for p in breakdown.find_all("p"):
                    body_parts.append(inline_all(p))
            body = "\n\n".join(indent_block(p) for p in body_parts)
            chunks.append(f'??? success "{answer_title}"\n\n{body}')
    return "\n\n".join(chunks)


def block_to_md(el, heading_level=3):
    """Render one block-level element (and, for <div class="sub-content"> etc,
    recurse into its children) as a list of Markdown chunks. heading_level is
    the level of the enclosing subsection -- an <h4 class="mini"> inside it
    renders one level deeper."""
    chunks = []
    for child in el.children:
        if isinstance(child, NavigableString):
            continue
        if not isinstance(child, Tag):
            continue
        if child.name == "p":
            chunks.append(inline_all(child))
        elif child.name == "h4":
            chunks.append(f"{'#' * (heading_level + 1)} {inline_all(child)}")
        elif child.name == "div" and "fact" in (child.get("class") or []):
            chunks.append(render_fact(child))
        elif child.name == "dl":
            chunks.append(render_dl(child))
        elif child.name == "pre":
            chunks.append(render_pre(child))
        elif child.name == "div" and "table-scroll" in (child.get("class") or []):
            chunks.append(render_table(child.find("table")))
        elif child.name == "table":
            chunks.append(render_table(child))
        elif child.name == "ol":
            chunks.append(render_list(child, ordered=True))
        elif child.name == "ul":
            chunks.append(render_list(child, ordered=False))
        elif child.name == "figure":
            chunks.append(render_figure(child))
        elif child.name == "details" and "strategy" in (child.get("class") or []):
            summary = child.find("summary")
            chev = summary.find("span", class_="chev-sm") if summary else None
            if chev:
                chev.extract()
            title = inline_all(summary) if summary else ""
            chunks.append(f"{'#' * (heading_level + 1)} {title}")
            body = child.find("div", class_="strategy-body")
            if body:
                chunks.extend(block_to_md(body, heading_level=heading_level + 1))
        elif child.name == "div" and "quiz" in (child.get("class") or []):
            chunks.append(render_quiz(child, heading_level))
        elif child.name == "div":
            # generic wrapper div -- recurse
            chunks.extend(block_to_md(child, heading_level=heading_level))
        else:
            chunks.append(inline_all(child))
    return chunks


def convert_day(day_tag, heading_level=2):
    """day_tag: <details class="day"> or <details class="sub">"""
    out = []
    summary = day_tag.find("summary", recursive=False)
    subnum = summary.find("span", class_=re.compile("sub-num|day-badge"))
    title_tag = summary.find(["h2", "h3"])
    title = inline_all(title_tag) if title_tag else ""
    prefix = "#" * heading_level
    num = subnum.get_text().strip() if subnum else ""
    heading = f"{prefix} {num} {title}".strip() if num else f"{prefix} {title}"
    out.append(heading)

    content = day_tag.find("div", class_=re.compile("day-body|sub-content"), recursive=False)
    if content is None:
        return "\n\n".join(out)

    for child in content.children:
        if isinstance(child, Tag) and child.name == "details" and "sub" in (child.get("class") or []):
            out.append(convert_day(child, heading_level=heading_level + 1))
        elif isinstance(child, Tag):
            out.extend(block_to_md(
                BeautifulSoup(f"<div>{child}</div>", "html.parser").div,
                heading_level=heading_level,
            ))

    return "\n\n".join(x for x in out if x.strip())


if __name__ == "__main__":
    src, day_id = sys.argv[1], sys.argv[2]
    day_num = int(re.match(r"^d(\d+)", day_id).group(1))
    build_anchor_map()
    CURRENT_TOPIC = DAY_TO_TOPIC.get((src, day_num))
    soup = BeautifulSoup(open(src), "html.parser")
    day = soup.find("details", id=day_id)
    print(convert_day(day))
