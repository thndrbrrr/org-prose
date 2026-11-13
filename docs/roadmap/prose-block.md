# Prose block (idea, not designed)

Nothing in this document exists yet. A `#+begin_prose` … `#+end_prose` special block would set
its contents as prose (body font, indented paragraphs, preview height) inside an entry that
isn't prose. That way a writing exercise can sit in the middle of a section's body without a
heading of its own.

## Background

`org-prose-mode` decides per entry whether its body is prose. Every decision goes through
`org-prose--noprose-p` (`org-prose.el`): the font-lock face `org-prose-noprose`, the paragraph
indentation and the preview height.

The `prose` tag (`org-prose-prose-tag`) has been added alongside `noprose`
(`org-prose-noprose-tag`). `org-get-tags` lists file tags first, then the tags of parent entries
from the outermost, then the entry's own. Of the two tags, the one that comes last (the one
nearest to the entry) decides. An entry with neither tag is prose. So a document that is mostly
not prose, such as one of instructions with writing exercises, can use `#+FILETAGS: noprose` and
tag the exercise headings `prose`.

Tags work per heading, though. An exercise in the middle of a section body has to get a heading
of its own to be prose. The block was proposed for when that is too heavy. The user agreed to
park it here and build the tag-only version first.

## Rough direction

Suggested, not agreed:

- Treat a paragraph as prose when it is inside a `prose` special block, whatever the entry's
  tags say. The block is the innermost marker, so it would take precedence over tags.
- Indentation: `org-prose--indent-line-p` only indents paragraphs whose parent type is in
  `org-prose--indented-parents` (`nil section quote-block center-block`). A paragraph inside the
  block has `special-block` as its parent, so the check would have to accept a special block of
  type `prose`, but not every special block.
- Font: `org-prose--match-noprose` matches whole entry bodies, from after the heading to the next
  heading. Inside a noprose entry it would have to leave out the block, by matching the parts
  before and after it separately. Otherwise the `org-prose-noprose` face would cover the block.
- Preview: the preview's flush-left layout (`org-prose--hidden-indentation`) and justification
  depend on the indent decision, so they should follow automatically. That still needs checking.

## Things to get right when building it

- The `#+begin_prose` and `#+end_prose` lines are in `org-block-begin-line` and
  `org-block-end-line`, which are in `org-prose-fixed-faces`, so they already keep the regular
  font.
- Export: Org exports a special block by its name, as `<div class="prose">` in HTML and as
  `\begin{prose}` in LaTeX. LaTeX fails unless that environment is defined. Has to be documented
  or handled.
- Refontification: editing the begin or end line changes how far the block reaches, and font
  lock only refontifies the changed lines (compare `org-prose--refontify-subtree` for heading
  tags).

## Decide first

1. Should there also be a `#+begin_noprose` block for notes inside a prose entry, to make the
   two sides match?
2. Should the block name be configurable, like the tags (`org-prose-prose-tag`)?
3. Should a prose block inside an entry that is already prose do anything, such as set off its
   contents visually, or be a no-op?

## When to build it

When a document needs prose exercises without headings of their own. Until then, use a heading
tagged `prose`.
