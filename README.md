# org-prose

[![License: GPL v3](https://img.shields.io/badge/License-GPL_v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

`org-prose` is a minor mode for writing prose in Org. Entry bodies are set in a serif font, every paragraph is indented like a book's, and quotes are typed curly. A preview shows the text enlarged and justified on a narrow page, so it reads as if it were typeset.

Headings, keywords, tables and other markup keep their regular font. Entries tagged `noprose`, such as notes, keep it for their body too.

## Demo

https://github.com/user-attachments/assets/53d90f7f-f6db-4d40-ac78-e1381357a9af

## Requirements

- Emacs 29.1 or newer, with Org 9.7 or newer
- [Olivetti](https://github.com/rnkn/olivetti), for the preview's margins
- The EB Garamond font, or another serif font in `org-prose-body-families`

## Installation

Install it from its repository, with `use-package` (Emacs 30) or `M-x package-vc-install`:

```elisp
(use-package org-prose
  :vc (:url "https://github.com/thndrbrrr/org-prose"))
```

Alternatively, clone the repository, add its directory to your `load-path`, and load it:

```elisp
(add-to-list 'load-path "/path/to/org-prose")
(require 'org-prose)
```

### Fonts

Body text is set in the first of these fonts that is installed:

| Font              | Where to get it                                                     |
|-------------------|---------------------------------------------------------------------|
| EB Garamond       | [Google Fonts](https://fonts.google.com/specimen/EB+Garamond)       |
| Libre Caslon Text | [Google Fonts](https://fonts.google.com/specimen/Libre+Caslon+Text) |
| Baskerville       | Comes with macOS                                                    |
| Libre Baskerville | [Google Fonts](https://fonts.google.com/specimen/Libre+Baskerville) |
| Palatino          | Comes with macOS                                                    |
| Georgia           | Comes with macOS and Windows                                        |

To use other fonts, or another order, set `org-prose-body-families`. If none of its fonts is installed, body text keeps the regular font.

## Usage

Turn it on in an Org buffer with `M-x org-prose-mode`, or for a file by adding to its first line:

```org
# -*- mode: org; eval: (org-prose-mode) -*-
```

While org-prose-mode is on:

- **Serif body text.** Entry bodies are set in `org-prose-body`, in the first font of `org-prose-body-families` that is installed: EB Garamond, else Libre Caslon Text, Baskerville, Libre Baskerville, Palatino or Georgia. Body text is 20pt (`org-prose-body-font-height`). Headings and the faces in `org-prose-fixed-faces`, for markup and line numbers, keep the regular font and size. Faces that your theme or another mode gives a font of their own, such as headings in a proportional font, keep it.
- **Indented paragraphs.** Every line of body text is indented by `org-prose-paragraph-indent` spaces, whether a blank line comes before it or not. Write each paragraph as one line and let `visual-line-mode` wrap it: wrapped lines aren't indented after the wrap, but lines filled with `M-q` or `auto-fill-mode` are each indented. List items, drawers and blocks other than quote and center blocks aren't indented.
- **Curly quotes.** Typed `'` and `"` become curly quotes, with `'` at the start of a word an opening one. Emacs's own `electric-quote-mode` does the curling; see [Quotes](#quotes).
- **Entries that aren't prose.** The body of an entry tagged `noprose` keeps the regular font and foreground and isn't indented. Sub-entries inherit the tag as `org-use-tag-inheritance` says.

### Preview

`M-x org-prose-toggle-preview` shows the buffer like a typeset book page. It sets all text at 24pt (`org-prose-preview-font-height`) and narrows the body with Olivetti to about 70 characters per line (`org-prose-preview-width`). Body text is justified: the spaces between words are widened so that every line of a paragraph but its last reaches the right margin. Comment lines (`# ...`) are hidden; `M-x org-prose-preview-toggle-comments` shows or hides them again in the buffer. Turning the preview off restores the text size and Olivetti as they were.

Body text in the preview is set in `org-prose-preview-body` on top of `org-prose-body`, so it can have a color of its own; see [Faces](#faces).

### Preview frame

`M-x org-prose-preview-frame` opens the preview in a frame of its own, black on white by default, whatever your Emacs theme. Body text has the foreground of the page, unless `org-prose-preview-body` gives it one for the page's background; see [Faces](#faces). You can write in your usual buffer or the preview frame. The frame shows an indirect buffer, so edits in either buffer appear in both.

The frame has two themes, `light` and `dark`. `org-prose-preview-frame-theme` picks the default one; with a prefix argument (`C-u M-x org-prose-preview-frame`) the command asks which to use. Running it again selects the existing frame and switches it to the theme you pick. Deleting the frame (`C-x 5 0`) kills its buffer, and killing the buffer deletes the frame.

### Keys

None of the common org-prose commands have a key, but here's a suggestion:

```elisp
(with-eval-after-load 'org-prose
  (keymap-set org-prose-mode-map "C-c p p" #'org-prose-toggle-preview)
  (keymap-set org-prose-mode-map "C-c p f" #'org-prose-preview-frame)
  (keymap-set org-prose-mode-map "C-c p c" #'org-prose-preview-toggle-comments))
```

## Customization

All options live under `M-x customize-group RET org-prose RET`.

- **`org-prose-body-families`** – The fonts for body text, in order of preference; the first one installed is used (EB Garamond, Libre Caslon Text, Baskerville, Libre Baskerville, Palatino, Georgia).
- **`org-prose-body-font-height`** – The height of body text outside the preview, in 1/10 pt (200), or, as a float, relative to the `default` face, such as 1.4. Headings, markup and `noprose` entries keep their regular height.
- **`org-prose-fixed-faces`**, **`org-prose-fixed-family`** – The faces that keep the regular font, besides those of headings (`org-level-faces`), and that font (the family of the `default` face if nil). Faces that set a font family of their own keep it.
- **`org-prose-paragraph-indent`** – How many spaces body text is indented by (4).
- **`org-prose-visual-line`** – Whether `org-prose-mode` turns on `visual-line-mode` (on by default).
- **`org-prose-noprose-tag`** – The tag of entries that aren't prose (`"noprose"`).
- **`org-prose-curly-quotes`** – Whether typed quotes become curly ones (on by default). It takes effect the next time `org-prose-mode` is turned on. See [Quotes](#quotes).
- **`org-prose-preview-font-height`** – The height of the text in the preview, in 1/10 pt (240), or, as a float, relative to the `default` face.
- **`org-prose-preview-width`** – About how many characters of body text fit on a line in the preview (70).
- **`org-prose-preview-justify`** – Whether the preview justifies body text (on by default). It works in graphical frames only.
- **`org-prose-preview-hide-comments`** – Whether the preview hides comment lines (on by default).
- **`org-prose-preview-fix-line-moves`** – Whether to work around an Emacs bug that makes moving up by screen lines skip a line in justified text (on by default). The workaround advises `vertical-motion` in preview buffers; turn it off if it gets in the way.
- **`org-prose-preview-frame-theme`** – The default theme of the preview frame, `light` or `dark` (`light`).
- **`org-prose-preview-frame-ignore-theme`** – Whether the faces of the preview frame have the default colors of Emacs instead of those of your theme (on by default).
- **`org-prose-preview-frame-width`** – The width of the preview frame, in columns of the frame's default font, as with the `width` frame parameter (140).
- **`org-prose-preview-frame-parameters`** – Frame parameters for the preview frame, such as `((fullscreen . maximized))`. They take precedence over the frame's default size: as tall as the screen and `org-prose-preview-frame-width` columns wide.

### Faces

Set them with `M-x customize-face`, or with `custom-set-faces` in your init file.

- **`org-prose-body`** – Body text, by default in the `default` face and the font of `org-prose-body-families`. A `:family` set here takes precedence over `org-prose-body-families`; a `:foreground` sets the color of body text, in and out of the preview, though not in the preview frame, whose page sets it.
- **`org-prose-noprose`** – The body of `noprose` entries. `org-prose-mode` gives it the regular font and foreground.
- **`org-prose-preview-body`** – Body text in the preview and in the preview frame, on top of `org-prose-body`. It's empty, so body text keeps the color of your theme, or in the preview frame that of the page. In the preview frame it takes precedence over the page face.
- **`org-prose-preview-light`**, **`org-prose-preview-dark`** – The page of each theme of the preview frame. The background is the color of the page, and the foreground and any font attributes, such as `:family`, are those of the body text. Light is #1a1a1a on #fffdf7, dark gray85 on #1c1c1c.
- **`org-prose-preview-light-heading`**, **`org-prose-preview-dark-heading`** – The color and font of headings in each theme of the preview frame.
- **`org-prose-preview-light-fixed`**, **`org-prose-preview-dark-fixed`** – The color and font of the other faces in `org-prose-fixed-faces` and of `noprose` entries in each theme of the preview frame.

To give body text in the preview a color of your choice, whatever your theme, give `org-prose-preview-body` a foreground for dark and for light backgrounds:

```elisp
(custom-set-faces
 '(org-prose-preview-body
   ((((background dark))  :foreground "gray85")
    (((background light)) :foreground "gray20"))))
```

Each frame uses the color for its own background: your frames the one that suits your theme, also after you switch it, and the preview frame the one that suits its page, light or dark. To change the color only on dark backgrounds, leave out the light one. A color without a background, as in `((t :foreground "gray85"))`, applies on every background, so it can be hard to read on a light theme or the light page of the preview frame.

### Quotes

Curly quotes come from `electric-quote-mode`. While `org-prose-curly-quotes` is on, `org-prose-mode` turns on `electric-quote-local-mode` in the buffer, unless the global `electric-quote-mode` is already on, and sets two of its options for the buffer only:

```elisp
(setq-local electric-quote-context-sensitive t ; ' at the start of a word opens a quote
            electric-quote-replace-double t)   ; " is curled too
```

Quotes typed in source and example blocks, fixed-width lines, keywords and property drawers stay straight. So do quotes typed into inline code or verbatim text that is already closed, such as between the tildes of `~code~`. While you type such text from left to right, its closing marker isn't there yet, so a quote typed in it is curled.

To set up quotes differently, turn `org-prose-curly-quotes` off, and `org-prose-mode` leaves quotes alone. Then configure electric quotes yourself, for example only for `org-prose-mode` buffers:

```elisp
(setq org-prose-curly-quotes nil)
(add-hook 'org-prose-mode-hook
          (lambda ()
            (setq-local electric-quote-replace-double nil    ; keep " straight
                        electric-quote-context-sensitive t) ; 'word → ‘word
            (electric-quote-local-mode (if org-prose-mode 1 -1))))
```

With `org-prose-curly-quotes` off, quotes typed in code are curled too, if electric quotes are on.

## License

Distributed under the terms of the GNU General Public License Version 3. See `LICENSE` for details.
