;;; org-prose.el --- Org minor mode for writing prose  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 thndrbrrr

;; Author: thndrbrrr <thndrbrrr@gmail.com>
;; Assisted-by: Claude:claude-opus-5-5
;; Maintainer: thndrbrrr <thndrbrrr@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.7") (olivetti "2.0"))
;; URL: https://github.com/thndrbrrr/org-prose
;; Keywords: outlines, wp

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `org-prose-mode' is a minor mode on top of `org-mode' for writing
;; prose:
;;
;; - Entry bodies are set in a serif font (face `org-prose-body'):
;;   the first of `org-prose-body-families' that is installed, EB
;;   Garamond by default, at `org-prose-body-font-height' (20pt).
;;   Headings, keywords, tables and other markup keep the regular
;;   font and size.
;; - Every line of body text is indented, whether or not a blank line
;;   precedes it (display only, the file is not changed).  Write each
;;   paragraph as one line and let `visual-line-mode' wrap it: lines
;;   it wraps are not indented after the wrap.
;; - Typed ' and " become curly quotes, except in code
;;   (`org-prose-curly-quotes').
;; - Entries tagged "noprose" (`org-prose-noprose-tag') keep the
;;   regular font and are not indented, e.g. for notes.
;;
;; `org-prose-preview-mode' (toggled with `org-prose-toggle-preview')
;; sets the text at `org-prose-preview-font-height' (24pt) and uses
;; Olivetti to narrow the body to about
;; `org-prose-preview-width' characters per line, so the text reads
;; like a typeset book page.  It justifies body text, widening the
;; spaces between words (`org-prose-preview-justify'), and hides
;; comment lines (# ...); toggle that with
;; `org-prose-preview-toggle-comments'.  Body text in preview is set
;; in `org-prose-preview-body' too, which can give it a color of its
;; own, such as gray85 on a dark theme.
;;
;; `org-prose-preview-frame' shows the preview in a frame of its own,
;; set in a light (black on white) or dark theme whatever the Emacs
;; theme.  The frame shows an indirect buffer, so edits in either
;; buffer appear in both.  Each theme's colors and fonts are set by its
;; faces, `org-prose-preview-light' and `org-prose-preview-dark'
;; with their -heading and -fixed variants.
;;
;; To enable it for a file, add to its first line:
;;
;;   # -*- mode: org; eval: (org-prose-mode) -*-
;;
;; Emacs doesn't ask before evaluating that, as `org-prose-mode' is
;; marked as a safe local eval function.

;;; Code:

(require 'org)
(require 'org-element)
(require 'face-remap)
(require 'color)
(require 'disp-table)
(require 'seq)

(declare-function olivetti-mode "olivetti")
(declare-function olivetti-scale-width "olivetti")
(declare-function olivetti-set-buffer-windows "olivetti")
(defvar olivetti-mode)
(defvar olivetti-body-width)
(defvar org-prose-mode)
(defvar org-prose-preview-mode)

(defgroup org-prose nil
  "Org minor mode for writing prose."
  :group 'org
  :prefix "org-prose-"
  :link '(url-link :tag "Website" "https://github.com/thndrbrrr/org-prose"))

(defface org-prose-body
  '((t))
  "Face for the body text of entries in `org-prose-mode'.
Its font family is the first of `org-prose-body-families' that is
installed, unless the face sets a :family of its own.  Its other
attributes, such as its color, are those of the `default' face unless
it sets them.  In `org-prose-preview-frame', the page face,
`org-prose-preview-light' or `org-prose-preview-dark', takes
precedence over it."
  :group 'org-prose)

(defcustom org-prose-body-families
  '("EB Garamond" "Libre Caslon Text" "Baskerville" "Libre Baskerville"
    "Palatino" "Georgia")
  "Font families for body text, in order of preference.
`org-prose-mode' sets body text in the first family that is
installed.  A :family set in the face `org-prose-body' takes
precedence over all of them."
  :type '(repeat string)
  :group 'org-prose)

(defcustom org-prose-fixed-faces
  '(org-document-title org-document-info org-document-info-keyword
    org-meta-line org-block org-block-begin-line org-block-end-line
    org-code org-verbatim org-table org-formula
    org-drawer org-special-keyword org-property-value
    org-date org-tag org-todo org-done org-priority org-checkbox
    org-hide org-indent org-latex-and-related
    org-modern-label org-modern-symbol
    line-number line-number-current-line)
  "Faces that keep the regular font instead of `org-prose-body'.
The faces of headings, `org-level-faces', keep it too.  Faces that are
not defined when the mode is enabled are skipped.

A face that sets a font family of its own, directly or through the
faces it inherits other than `default', keeps it: as with a theme's
headings, or the `fixed-pitch' faces of `mixed-pitch-mode'."
  :type '(repeat face)
  :group 'org-prose)

(defface org-prose-noprose nil
  "Face for the body text of entries tagged `org-prose-noprose-tag'.
`org-prose-mode' sets it to the regular font and foreground."
  :group 'org-prose)

(defcustom org-prose-noprose-tag "noprose"
  "Tag for entries whose body is not prose.
Their body keeps the regular font and is not indented.  Subentries
inherit the tag as set by `org-use-tag-inheritance'."
  :type 'string
  :group 'org-prose)

(defcustom org-prose-fixed-family nil
  "Font family for `org-prose-fixed-faces'.
When nil, use the family of the frame's `default' face.  Faces that
set a family of their own keep it."
  :type '(choice (const :tag "Default face's family" nil) string)
  :group 'org-prose)

(defcustom org-prose-body-font-height 200
  "Height of body text in `org-prose-mode'.
An integer is a height in 1/10 pt, a float one relative to the
`default' face, such as 1.4 for 40% larger.  Headings, markup and the
body of noprose entries keep their regular height.
`org-prose-preview-mode' sets all text at
`org-prose-preview-font-height' instead."
  :type '(choice (natnum :tag "In 1/10 pt")
                 (float :tag "Relative to the default font"))
  :group 'org-prose)

(defcustom org-prose-paragraph-indent 4
  "Number of spaces to indent each line of body text by."
  :type 'natnum
  :group 'org-prose)

(defcustom org-prose-visual-line t
  "Non-nil means `org-prose-mode' turns on `visual-line-mode'.
Each paragraph is written as a single line, which then wraps between
words to the width of the window, where Org would truncate it by
default (`org-startup-truncated').  Turning `org-prose-mode' off
turns `visual-line-mode' off again if it turned it on."
  :type 'boolean
  :group 'org-prose)

(defcustom org-prose-curly-quotes t
  "Non-nil means `org-prose-mode' turns typed quotes into curly ones.
It turns on `electric-quote-local-mode', unless `electric-quote-mode'
is on, and sets `electric-quote-context-sensitive' and
`electric-quote-replace-double' to t in the buffer: ' at the start of
a word becomes an opening quote, and \" is curled too.  Quotes typed
in source and example blocks, fixed-width lines, keywords and property
drawers stay straight, as do quotes typed into inline source code,
code or verbatim text that is already closed, such as between the
tildes of ~code~.  While such text is typed from left to right, its
closing marker isn't there yet, so a quote typed in it is curled.

If nil, `org-prose-mode' leaves quotes to your own electric-quote
settings.  The change takes effect the next time the mode is turned
on."
  :type 'boolean
  :group 'org-prose)

(defcustom org-prose-preview-font-height 240
  "Height of the text in `org-prose-preview-mode'.
An integer is a height in 1/10 pt, a float one relative to the
`default' face, such as 1.7 for 70% larger."
  :type '(choice (natnum :tag "In 1/10 pt")
                 (float :tag "Relative to the default font"))
  :group 'org-prose)

(defcustom org-prose-preview-width 70
  "Approximate number of body characters per line in preview."
  :type 'natnum
  :group 'org-prose)

(defcustom org-prose-preview-justify t
  "Non-nil means `org-prose-preview-mode' justifies body text.
The spaces between words are widened so that every line of a
paragraph but its last fills the width of the page.  Only lines that
`org-prose-mode' indents are justified, in graphical frames with
`word-wrap' on."
  :type 'boolean
  :group 'org-prose)

(defcustom org-prose-preview-hide-comments t
  "Non-nil means `org-prose-preview-mode' hides comment lines.
Toggle it per buffer with `org-prose-preview-toggle-comments'."
  :type 'boolean
  :group 'org-prose)

(defcustom org-prose-preview-frame-theme 'light
  "Theme of `org-prose-preview-frame', `light' or `dark'.
The faces `org-prose-preview-light' and `org-prose-preview-dark',
with their -heading and -fixed variants, set each theme's colors and
fonts."
  :type '(choice (const :tag "Light" light) (const :tag "Dark" dark))
  :group 'org-prose)

(defcustom org-prose-preview-frame-width 140
  "Width of `org-prose-preview-frame', in columns.
Columns are as wide as the characters of the frame's default font, as
with the `width' frame parameter, not of the body text."
  :type 'natnum
  :group 'org-prose)

(defcustom org-prose-preview-frame-ignore-theme t
  "Non-nil means the preview frame doesn't take colors from the Emacs theme.
Its faces, such as those of links, source code, the mode line and the
tab line, then have their default colors for the frame's light or
dark background, with any you set with Customize, so that they read
well on the page.  Their fonts are kept.  If nil, they keep the colors
of the Emacs theme, made for its own background."
  :type 'boolean
  :group 'org-prose)

(defcustom org-prose-preview-frame-parameters nil
  "Frame parameters of `org-prose-preview-frame'.
They take precedence over the frame's default size, which is the full
height of the screen and `org-prose-preview-frame-width' columns."
  :type '(alist :key-type symbol :value-type sexp)
  :group 'org-prose)

(defface org-prose-preview-body
  '((t))
  "Face for the body text of entries in preview.
It applies on top of `org-prose-body' in `org-prose-preview-mode' and
in `org-prose-preview-frame', where it also takes precedence over the
page face, `org-prose-preview-light' or `org-prose-preview-dark'.
Give it a :foreground to set the color of body text in preview,
whatever the Emacs theme.  Of a spec for dark and light backgrounds,
each frame uses the one for its own background: the preview frame
that of its page.  For example:

  (custom-set-faces
   \\='(org-prose-preview-body
     ((((background dark)) :foreground \"gray85\")
      (((background light)) :foreground \"gray20\"))))"
  :group 'org-prose)

(defface org-prose-preview-light
  '((t :background "#fffdf7" :foreground "#1a1a1a"))
  "Face for the page in a light preview frame.
Its background is the color of the page, its foreground and any font
attributes those of the body text.  See `org-prose-preview-frame'."
  :group 'org-prose)

(defface org-prose-preview-light-heading
  '((t :foreground "#1a1a1a"))
  "Face for headings in a light preview frame."
  :group 'org-prose)

(defface org-prose-preview-light-fixed
  '((t :foreground "#6b6b6b"))
  "Face for markup and noprose entries in a light preview frame.
It applies to `org-prose-fixed-faces' other than headings, and to
`org-prose-noprose'."
  :group 'org-prose)

(defface org-prose-preview-dark
  '((t :background "#1c1c1c" :foreground "gray85"))
  "Face for the page in a dark preview frame.
Its background is the color of the page, its foreground and any font
attributes those of the body text.  See `org-prose-preview-frame'."
  :group 'org-prose)

(defface org-prose-preview-dark-heading
  '((t :foreground "gray92"))
  "Face for headings in a dark preview frame."
  :group 'org-prose)

(defface org-prose-preview-dark-fixed
  '((t :foreground "gray55"))
  "Face for markup and noprose entries in a dark preview frame.
It applies to `org-prose-fixed-faces' other than headings, and to
`org-prose-noprose'."
  :group 'org-prose)

(defun org-prose--heading-faces ()
  "Return the faces of headings.
They are those of `org-level-faces' and `org-document-title'.  A
preview theme's heading face sets their attributes."
  (cons 'org-document-title org-level-faces))

(defun org-prose--fixed-faces ()
  "Return the defined faces that keep the regular font.
They are those of headings and `org-prose-fixed-faces'."
  (seq-filter #'facep
              (seq-union (org-prose--heading-faces) org-prose-fixed-faces)))

(defconst org-prose--indented-parents '(nil section quote-block center-block)
  "Types of elements whose child paragraphs get indented.")

(defconst org-prose--sample-text
  (concat "The evening light fell across the quiet harbour "
          "as she turned, at last, toward home.")
  "Text used to measure the average character width of `org-prose-body'.")

(defvar-local org-prose--remap-cookies nil
  "Face remapping cookies added by `org-prose-mode'.")

(defvar-local org-prose--height-cookies nil
  "Face remapping cookies added by `org-prose--update-heights'.")

(defvar-local org-prose--preview-saved nil
  "Settings to restore when `org-prose-preview-mode' is turned off.")

(defvar-local org-prose--preview-theme nil
  "Theme of a preview frame's buffer, `light' or `dark', or nil.")

(defvar-local org-prose--text-width nil
  "Width in pixels that the preview was last laid out for, or nil.
Body text is justified and heading tags are aligned to it.")

(defvar-local org-prose--quotes-set-up nil
  "Non-nil if `org-prose-mode' set up curly quotes in the buffer.")

(defvar-local org-prose--electric-quote-enabled nil
  "Non-nil if `org-prose-mode' turned on `electric-quote-local-mode'.")

(defvar-local org-prose--visual-line-enabled nil
  "Non-nil if `org-prose-mode' turned on `visual-line-mode'.")

(defvar-local org-prose--faces-deferred nil
  "Non-nil if the buffer's fonts wait for a graphical frame.
See `org-prose--graphic-frame'.")

(defvar-local org-prose--width-timer nil
  "Timer to lay out the preview again for a new width, or nil.")

(defconst org-prose--font-lock-keywords
  '((org-prose--match-noprose (0 'org-prose-noprose append)))
  "Font lock keywords added by `org-prose-mode'.")

;;;; Noprose entries

(defun org-prose--noprose-p ()
  "Return non-nil if point is in an entry tagged `org-prose-noprose-tag'."
  (member org-prose-noprose-tag (ignore-errors (org-get-tags))))

(defun org-prose--match-noprose (limit)
  "Match the next body of a noprose entry before LIMIT.
Font lock matcher for `org-prose--font-lock-keywords'."
  (let (found)
    (while (and (not found) (< (point) limit))
      (if (org-at-heading-p)
          (forward-line 1)
        (let ((beg (point))
              (end (min limit (save-excursion (outline-next-heading) (point)))))
          (when (and (< beg end) (org-prose--noprose-p))
            (set-match-data (list beg end))
            (setq found t))
          (goto-char end))))
    found))

(defun org-prose--refontify-subtree (beg _end _len)
  "Refontify the subtree if the change at BEG is on a heading.
Its tags decide the body's font, but font lock only refontifies the
changed lines.  Added to `after-change-functions'."
  (save-excursion
    (goto-char beg)
    (when (org-at-heading-p)
      (font-lock-flush (line-beginning-position)
                       (save-excursion (org-end-of-subtree t t) (point))))))

;;;; Indentation and comments

(defun org-prose--indent-line-p (el)
  "Return non-nil if the line at point, in element EL, is body text to indent."
  (and (eq (org-element-type el) 'paragraph)
       (>= (point) (org-element-property :post-affiliated el))
       (not (looking-at-p "[ \t]*$"))
       (memq (org-element-type (org-element-property :parent el))
             org-prose--indented-parents)
       (not (org-prose--noprose-p))))

(defun org-prose--indent-string ()
  "Return the indentation string for a line of body text.
It is in the `default' face: redisplay would draw it in the face of
the text it comes before, such as that of code."
  (propertize (make-string org-prose-paragraph-indent ?\s) 'face 'default))

(defun org-prose--make-overlay (beg end kind &rest props)
  "Make an overlay of KIND from BEG to END.
KIND is `indent', `comment', `flush', `lead', `justify' or `tags'.
PROPS are further overlay properties and values."
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'org-prose kind)
    (overlay-put ov 'evaporate t)
    (while props
      (overlay-put ov (pop props) (pop props)))))

(defun org-prose--text-buffers ()
  "Return the buffers in `org-prose-mode' sharing the current buffer's text.
These are its base buffer and the base buffer's indirect buffers."
  (let ((base (or (buffer-base-buffer) (current-buffer))))
    (seq-filter (lambda (buf)
                  (and (eq (or (buffer-base-buffer buf) buf) base)
                       (buffer-local-value 'org-prose-mode buf)))
                (buffer-list))))

(defun org-prose--overlay-region (beg end)
  "Indent body text and mark comment lines between BEG and END.
Comment lines are hidden by `org-prose--update-comment-visibility'.
In buffers in `org-prose-preview-mode', also set every line flush with
the left edge of the page, justify body text and align the tags of
headings to the right edge of the page.
Registered with `jit-lock-register'."
  (save-excursion
    (save-match-data
      ;; Whether a line is body text depends on its neighbours, so look
      ;; one line beyond the region on either side.
      (goto-char beg)
      (forward-line -1)
      (setq beg (point))
      (goto-char end)
      (forward-line 1)
      (setq end (line-end-position))
      (let (overlays prose-lines tag-lines flush-lines)
        (goto-char beg)
        (while (< (point) end)
          (let* ((el (ignore-errors (org-element-at-point)))
                 (heading (eq (org-element-type el) 'headline))
                 (indent (org-prose--indent-line-p el)))
            ;; The line, the end of what to hide at its start in the
            ;; preview (the leading stars of a heading, else level
            ;; indentation), and its wrap prefix without level
            ;; indentation.
            (let ((lead-end (if heading
                                (and (looking-at "\\(\\**\\)\\*")
                                     (match-end 1))
                              (+ (point)
                                 (org-prose--hidden-indentation el indent)))))
              (push (list (point) (min (1+ (pos-eol)) (point-max)) lead-end
                          (if heading
                              ""
                            (org-prose--flush-wrap-prefix
                             (point) (- lead-end (point)))))
                    flush-lines))
            (cond
             ((and heading (looking-at org-tag-line-re))
              ;; The spaces before the tags, and the tags.
              (let ((tags-beg (match-beginning 1)))
                (save-excursion
                  (goto-char tags-beg)
                  (skip-chars-backward " \t" (line-beginning-position))
                  (when (< (point) tags-beg)
                    (push (list (point) tags-beg (match-end 1)) tag-lines)))))
             (indent
              (skip-chars-forward " \t")
              (push (list (point) (1+ (point)) 'indent
                          'before-string (org-prose--indent-string))
                    overlays)
              (push (cons (point) (line-end-position)) prose-lines))
             ((and (eq (org-element-type el) 'comment)
                   (not (looking-at-p "[ \t]*$")))
              ;; Include the newline so the hidden line takes no space.
              (push (list (point) (min (1+ (line-end-position)) (point-max))
                          'comment 'invisible 'org-prose-comment)
                    overlays))))
          (forward-line 1))
        ;; Indirect buffers share text properties, including the one
        ;; that tells jit-lock a region is done, so whichever buffer
        ;; shows the region first updates the overlays of all of them.
        (dolist (buf (org-prose--text-buffers))
          (with-current-buffer buf
            (dolist (ov (overlays-in beg end))
              (when (overlay-get ov 'org-prose)
                (delete-overlay ov)))
            (dolist (args overlays)
              (apply #'org-prose--make-overlay args))
            ;; Before justifying, which measures the prefixes of lines.
            (when org-prose-preview-mode
              (dolist (line flush-lines)
                (org-prose--flush-line line)))
            (when-let* ((window (org-prose--preview-window)))
              (org-prose--note-width window)
              (with-demoted-errors "org-prose: can't align tags: %S"
                (dolist (line tag-lines)
                  (apply #'org-prose--align-tags (append line (list window))))))
            (when-let* ((window (org-prose--justify-window)))
              (with-demoted-errors "org-prose: can't justify: %S"
                (let ((width (org-prose--text-area-width window)))
                  (dolist (line prose-lines)
                    (org-prose--justify-line
                     (car line) (cdr line) window width)))))))))))

;;;; Flush lines

;; In the preview, every line starts at the left edge of the page, as in
;; a book.  `org-indent-mode' indents lines by the level of their entry
;; with `line-prefix' and `wrap-prefix' text properties.  Text properties
;; are shared with indirect buffers, such as the preview frame's, so
;; overlays, which belong to one buffer and take precedence, set the
;; prefixes instead.  The leading stars of headings, which indent them
;; by level, are hidden, so their last star, or the bullet that modes
;; such as `org-modern-mode' show for it, starts at the left edge.
;;
;; Files written with `org-adapt-indentation' indent the text of entries
;; with spaces instead.  That indentation is hidden too, as much of it
;; as the outermost element of the line in its entry has, so that nested
;; list items and the lines of source blocks keep their indentation
;; relative to it.

(defun org-prose--base-indentation (el)
  "Return the indentation of the outermost element in its entry around EL.
That is the number of spaces and tabs its first line starts with."
  (let ((top el)
        parent)
    (while (and (setq parent (org-element-property :parent top))
                (not (memq (org-element-type parent)
                           '(section headline org-data))))
      (setq top parent))
    (save-excursion
      (goto-char (or (org-element-property :post-affiliated top)
                     (org-element-property :begin top)))
      (skip-chars-forward " \t" (pos-eol))
      (- (point) (pos-bol)))))

(defun org-prose--hidden-indentation (el indent)
  "Return how many characters at the start of the line at point to hide.
They are hidden in the preview to set the line flush with the left
edge of the page.  EL is the element at point, and INDENT non-nil if
the line is body text, whose indentation is all hidden."
  (let ((indentation (save-excursion
                       (skip-chars-forward " \t" (pos-eol))
                       (- (point) (pos-bol)))))
    (cond
     ((or (zerop indentation) (null el)) 0)
     (indent indentation)
     (t (min indentation (org-prose--base-indentation el))))))

(defun org-prose--flush-wrap-prefix (pos hidden)
  "Return the wrap prefix of the line at POS without level indentation.
That is the part of its `wrap-prefix' beyond its `line-prefix', as
`org-indent-mode' sets them: for a list item, the indentation of its
wrapped lines to its text.  As HIDDEN characters of indentation are
hidden at the start of the line, as many leading spaces are left out
of it too."
  (let ((line (get-text-property pos 'line-prefix))
        (wrap (get-text-property pos 'wrap-prefix)))
    (if (not (stringp wrap))
        ""
      (let ((wrap (if (stringp line)
                      (substring wrap (min (length line) (length wrap)))
                    wrap)))
        (string-match "\\`[ \t]*" wrap)
        (substring wrap (min hidden (match-end 0)))))))

(defun org-prose--flush-line (line)
  "Set LINE flush with the left edge of the page.
LINE is a list (BEG END LEAD-END WRAP-PREFIX): the line from BEG to
END is given no line prefix and WRAP-PREFIX as its wrap prefix.  If
LEAD-END is non-nil, the text from BEG to LEAD-END is hidden: the
leading stars of a heading, all but its last star, or indentation."
  (pcase-let ((`(,beg ,end ,lead-end ,wrap-prefix) line))
    (org-prose--make-overlay beg end 'flush
                             'line-prefix "" 'wrap-prefix wrap-prefix)
    (when (and lead-end (< beg lead-end))
      (org-prose--make-overlay beg lead-end 'lead
                               'invisible 'org-prose-lead))))

;;;; Heading tags

;; Org aligns the tags of a heading with spaces, to `org-tags-column'.
;; In the preview, headings are larger and the page narrower than that
;; column, so the heading would wrap within the spaces.  Instead, the
;; spaces are displayed as a stretch that ends where the tags must start
;; to end at the right edge of the page, whatever its width.
;;
;; When the heading is folded, Org shows an ellipsis after the tags.
;; Folding doesn't change the text, so the stretch has two widths, and a
;; condition that redisplay evaluates picks the one that leaves room for
;; the ellipsis when the heading is folded.

(defun org-prose--string-pixel-width-as-displayed (string window)
  "Return the width in pixels of STRING as redisplay lays it out in WINDOW.
Unlike `org-prose--string-pixel-width', this includes the boxes of
faces and the faces that display strings take from the text they
replace.  The current buffer's face remapping and invisibility spec
apply.  STRING is measured in a buffer of its own, so it isn't
wrapped."
  (let ((remapping face-remapping-alist)
        (invisibility buffer-invisibility-spec)
        (display-table buffer-display-table))
    (with-temp-buffer
      (setq-local face-remapping-alist remapping
                  buffer-invisibility-spec invisibility
                  buffer-display-table display-table)
      (insert string)
      (car (buffer-text-pixel-size nil window)))))

(defun org-prose--displayed-text (beg end)
  "Return the text from BEG to END with the properties it is displayed with.
These are its text properties and, merged on top, the `display',
`invisible' and `face' properties and the before and after strings
of the overlays on it, other than those of org-prose.  The prefixes
of the line are left out."
  (let ((text (buffer-substring beg end))
        before after)
    ;; `org-indent-mode' puts the indentation of the line in these.
    (remove-text-properties 0 (length text)
                            '(line-prefix nil wrap-prefix nil) text)
    (dolist (ov (overlays-in beg end))
      (unless (overlay-get ov 'org-prose)
        (let ((from (- (max beg (overlay-start ov)) beg))
              (to (- (min end (overlay-end ov)) beg)))
          (when (< from to)
            (dolist (prop '(display invisible))
              (when-let* ((value (overlay-get ov prop)))
                (put-text-property from to prop value text)))
            (when-let* ((face (overlay-get ov 'face)))
              (add-face-text-property from to face nil text)))
          (when-let* (((>= (overlay-start ov) beg))
                      (string (overlay-get ov 'before-string)))
            (push string before))
          (when-let* (((<= (overlay-end ov) end))
                      (string (overlay-get ov 'after-string)))
            (push string after)))))
    (apply #'concat (append before (list text) after))))

(defun org-prose--text-pixel-width (beg end window)
  "Return the width in pixels of the text from BEG to END in WINDOW.
Unlike `org-prose--char-widths', this lays the text out as redisplay
does, as with tags that `org-modern-mode' shows as labels; see
`org-prose--displayed-text' and
`org-prose--string-pixel-width-as-displayed'."
  (org-prose--string-pixel-width-as-displayed
   (org-prose--displayed-text beg end) window))

(defun org-prose--ellipsis-width (pos window)
  "Return the width in pixels of the ellipsis for invisible text at POS.
That is the ellipsis of WINDOW's display table, else of the buffer's
or the standard one, else \"...\".  Like redisplay, this sets it in the
face of the character before POS, with the face of each glyph, if
any, merged on top."
  (let* ((table (or (window-display-table window)
                    buffer-display-table
                    standard-display-table))
         (glyphs (and table (display-table-slot table 'selective-display)))
         (face (and (> pos (point-min))
                    (get-char-property (1- pos) 'face)))
         ;; A list of faces, or a single face or anonymous face.
         (faces (if (and (consp face) (not (keywordp (car face))))
                    face
                  (and face (list face))))
         (string (if glyphs
                     (mapconcat
                      (lambda (glyph)
                        (propertize (string (glyph-char glyph))
                                    'face (if-let* ((own (glyph-face glyph)))
                                              (cons own faces)
                                            faces)))
                      glyphs "")
                   (propertize "..." 'face faces))))
    (org-prose--string-pixel-width-as-displayed string window)))

(defun org-prose--folded-p (pos)
  "Return non-nil if the heading at POS is folded with an ellipsis.
Its line then ends in invisible text that the buffer's invisibility
spec replaces with an ellipsis.  Evaluated by redisplay, in the buffer
it displays."
  (let ((eol (save-excursion (goto-char pos) (pos-eol))))
    (and (< eol (point-max))
         ;; `invisible-p' returns t for text hidden without an ellipsis.
         (let ((invisible (invisible-p eol)))
           (and invisible (not (eq invisible t)))))))

(defun org-prose--align-tags (gap-beg tags-beg tags-end window)
  "Align the tags from TAGS-BEG to TAGS-END to the right edge of WINDOW.
GAP-BEG is the start of the spaces before them.  If the heading is
folded, the tags end early enough for the ellipsis to fit after them."
  (let* ((tags-width (org-prose--text-pixel-width tags-beg tags-end window))
         ;; What `org-prose--text-area-width' keeps free at the edge.
         ;; `right' is the right edge whatever the line numbers.
         (margin (- (window-body-width window t)
                    (org-prose--line-number-width window)
                    (org-prose--text-area-width window)))
         (ellipsis-width (org-prose--ellipsis-width
                          (save-excursion (goto-char tags-end) (pos-eol))
                          window)))
    (org-prose--make-overlay
     gap-beg tags-beg 'tags
     'display
     ;; The first of these that applies is used.
     `((when (org-prose--folded-p buffer-position)
         space :align-to (- right (,(+ tags-width margin ellipsis-width))))
       (space :align-to (- right (,(+ tags-width margin))))))))

;;;; Justification

;; Body text is justified by widening the spaces between words with
;; `display' overlays.  `word-wrap' still breaks the lines: the text is
;; broken the way it would break them, measured glyph by glyph in the
;; fonts of the window that shows it, and each line but a paragraph's
;; last is filled to the width of the window.  The spaces at the breaks
;; are given no width, so a filled line still fits.

(defun org-prose--preview-window ()
  "Return the window to lay out the current buffer's preview for, or nil.
That is the selected window if it shows the buffer, else another one,
if the buffer is in `org-prose-preview-mode' and the window is in a
graphical frame."
  (and org-prose-preview-mode
       (let ((window (if (eq (window-buffer) (current-buffer))
                         (selected-window)
                       (get-buffer-window nil t))))
         (and window
              (display-graphic-p (window-frame window))
              window))))

(defun org-prose--justify-window ()
  "Return the window to justify the current buffer's body text for, or nil.
That is `org-prose--preview-window', if body text is to be justified."
  (and org-prose-preview-justify
       word-wrap
       (not truncate-lines)
       (org-prose--preview-window)))

(defun org-prose--glyph-width (font pos &optional object)
  "Return the width in pixels of FONT's glyph for the character at POS.
POS is an index into the string OBJECT if non-nil, else a position in
the current buffer.  Return nil if FONT has no glyph for it."
  (when-let* ((glyph (aref (font-get-glyphs font pos (1+ pos) object) 0)))
    (aref glyph 4)))

(defun org-prose--string-pixel-width (string window)
  "Return the width in pixels of STRING displayed in WINDOW.
WINDOW must show the current buffer, whose face remapping applies."
  (let ((remap (cdr (assq 'default face-remapping-alist)))
        (string (copy-sequence string))
        (width 0))
    ;; `font-at' takes the faces of a string to be relative to the
    ;; `default' face as it is not remapped, so add the remapping.
    (dolist (face (if (or (symbolp remap) (keywordp (car remap)))
                      (list remap)
                    remap))
      (unless (memq face '(nil default))
        (add-face-text-property 0 (length string) face t string)))
    (dotimes (i (length string))
      (unless (invisible-p (get-text-property i 'invisible string))
        (setq width (+ width (or (org-prose--glyph-width
                                  (font-at i window string) i string)
                                 0)))))
    width))

(defun org-prose--foreign-property (pos prop)
  "Return PROP at POS of the overlays not made by org-prose, else of the text."
  (or (seq-some (lambda (ov)
                  (and (not (overlay-get ov 'org-prose))
                       (overlay-get ov prop)))
                (overlays-at pos t))
      (get-text-property pos prop)))

(defun org-prose--boxed-p (face)
  "Return non-nil if FACE, the value of a `face' property, draws a box."
  (cond
   ((and face (symbolp face))
    (and (facep face)
         (not (memq (face-attribute face :box nil t) '(nil unspecified)))))
   ((and (consp face) (keywordp (car face)))
    (or (not (memq (plist-get face :box) '(nil unspecified)))
        (org-prose--boxed-p (plist-get face :inherit))))
   ((consp face)
    (seq-some #'org-prose--boxed-p face))))

(defun org-prose--plain-run-p (beg end)
  "Return non-nil if the text from BEG to END can be measured glyph by glyph.
It can't if redisplay composes it, as `org-pretty-entities' or
ligatures do, replaces it, as with images or display strings, draws it
in a box, or adds strings to it from overlays.  The text has the same
properties throughout."
  (and (not (get-text-property beg 'composition))
       (not (org-prose--foreign-property beg 'display))
       (not (org-prose--boxed-p (get-char-property beg 'face)))
       (not (seq-some (lambda (ov)
                        (and (not (overlay-get ov 'org-prose))
                             (or (overlay-get ov 'before-string)
                                 (overlay-get ov 'after-string))))
                      (overlays-in beg end)))
       (not (and auto-composition-mode
                 (save-excursion
                   (goto-char beg)
                   (catch 'composed
                     (while (< (point) end)
                       (when (aref composition-function-table (char-after))
                         (throw 'composed t))
                       (forward-char))))))))

(defun org-prose--measure-run (beg end window widths offset)
  "Measure the text from BEG to END as redisplay lays it out in WINDOW.
Each run of spaces or of other characters gets its width on its first
character in the vector WIDTHS, whose first element is the character
at OFFSET.  Each run is measured with all the text before it, so that
a display string or box that covers several of them counts once."
  (let ((pos beg)
        (before 0))
    (save-excursion
      (while (< pos end)
        (goto-char pos)
        (if (memq (char-after) '(?\s ?\t))
            (skip-chars-forward " \t" end)
          (skip-chars-forward "^ \t" end))
        (let ((width (org-prose--string-pixel-width-as-displayed
                      (org-prose--displayed-text beg (point)) window)))
          (aset widths (- pos offset) (max 0 (- width before)))
          (setq before (max before width)
                pos (point)))))))

(defun org-prose--char-widths (beg end window)
  "Return the widths in pixels of the characters from BEG to END in WINDOW.
The value is a vector with one element per character.  Invisible
characters have no width.  Text that can't be measured glyph by glyph,
see `org-prose--plain-run-p', is measured as redisplay lays it out:
each of its words and runs of spaces has its width on its first
character."
  (let ((widths (make-vector (- end beg) 0))
        (pos beg))
    (while (< pos end)
      (let ((next (next-char-property-change pos end)))
        (cond
         ((invisible-p pos))
         ((not (org-prose--plain-run-p pos next))
          (org-prose--measure-run pos next window widths beg))
         (t
          (let ((glyphs (font-get-glyphs (font-at pos window) pos next)))
            (dotimes (i (- next pos))
              (let ((glyph (aref glyphs i)))
                (aset widths (+ (- pos beg) i)
                      (if glyph
                          (aref glyph 4)
                        ;; The character is shown in a font of its own.
                        (let ((p (+ pos i)))
                          (or (org-prose--glyph-width (font-at p window) p)
                              0)))))))))
        (setq pos next)))
    widths))

(defun org-prose--line-number-width (window)
  "Return the width in pixels of the line numbers in WINDOW, or 0.
They are displayed in the text area, see `display-line-numbers'.  The
width is that of the last redisplay of WINDOW."
  (if (buffer-local-value 'display-line-numbers (window-buffer window))
      (with-selected-window window
        (line-number-display-width t))
    0))

(defun org-prose--text-area-width (window)
  "Return the width in pixels that a line of text can fill in WINDOW.
That is the text area without its line numbers, if any, and a pixel
less: a line that ends right at its edge is not always wrapped after
the space that follows it."
  (- (window-body-width window t)
     (org-prose--line-number-width window)
     1
     ;; Without a right fringe, the last column shows `\' on wrapped lines.
     (if (zerop (or (cadr (window-fringes window)) 0))
         (org-prose--string-pixel-width "\\" window)
       0)))

(defun org-prose--prefix-width (prop pos window)
  "Return the width in pixels of the PROP prefix at POS in WINDOW.
PROP is `line-prefix' or `wrap-prefix'.  Prefixes that are not strings
are taken to have no width."
  (let ((prefix (or (get-char-property pos prop) (symbol-value prop))))
    (if (stringp prefix)
        (org-prose--string-pixel-width prefix window)
      0)))

(defun org-prose--justify-line (beg end window width)
  "Justify the body text from BEG to END, a single line, for WINDOW.
WIDTH is the width in pixels that the text can fill."
  (let* ((bol (save-excursion (goto-char beg) (line-beginning-position)))
         (widths (org-prose--char-widths bol end window))
         (sums (make-vector (1+ (length widths)) 0))
         words lines)
    (dotimes (i (length widths))
      (aset sums (1+ i) (+ (aref sums i) (aref widths i))))
    ;; WORDS holds (GAP-BEG WORD-BEG WORD-END GAP-WIDTH WORD-WIDTH) for
    ;; each word, where the gap is the run of spaces before the word.
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (let ((gap-beg (point)))
          (skip-chars-forward " \t" end)
          (let ((word-beg (point)))
            (skip-chars-forward "^ \t" end)
            (when (< word-beg (point))
              (push (list gap-beg word-beg (point)
                          (- (aref sums (- word-beg bol))
                             (aref sums (- gap-beg bol)))
                          (- (aref sums (- (point) bol))
                             (aref sums (- word-beg bol))))
                    words))))))
    (setq words (nreverse words))
    ;; Break the text into lines as `word-wrap' does, each line being
    ;; (AVAILABLE-WIDTH NATURAL-WIDTH WORDS...).
    (let ((avail (- width
                    (org-prose--prefix-width 'line-prefix bol window)
                    ;; Any leading whitespace and the indentation, in
                    ;; the `default' face.
                    (aref sums (- beg bol))
                    (org-prose--string-pixel-width
                     (make-string org-prose-paragraph-indent ?\s) window)))
          (wrap-avail
           (- width (org-prose--prefix-width 'wrap-prefix beg window)))
          (x 0)
          line)
      (dolist (word words)
        (let ((gap (if line (nth 3 word) 0))
              (word-width (nth 4 word)))
          (if (and line (> (+ x gap word-width) avail))
              (progn
                (push (cons avail (cons x (nreverse line))) lines)
                (setq line (list word)
                      x word-width
                      avail wrap-avail))
            (push word line)
            (setq x (+ x gap word-width)))))
      (when line
        (push (cons avail (cons x (nreverse line))) lines)))
    (setq lines (nreverse lines))
    ;; Stretch the gaps in every line but the last one.
    (dolist (line (butlast lines))
      (pcase-let* ((`(,avail ,natural ,_first . ,rest) line)
                   (gaps (length rest)))
        (when (and (> gaps 0) (> avail natural))
          (let ((extra (/ (- avail natural) gaps))
                (remainder (% (- avail natural) gaps))
                (i 0))
            (dolist (word rest)
              (org-prose--make-overlay
               (nth 0 word) (nth 1 word) 'justify
               'display `(space :width (,(+ (nth 3 word) extra
                                            (if (< i remainder) 1 0)))))
              (setq i (1+ i)))))))
    ;; Give the gaps at the breaks, before every line but the first, no
    ;; width, or the filled lines would not fit.
    (dolist (line (cdr lines))
      (let ((first (nth 2 line)))
        (when (< (nth 0 first) (nth 1 first))
          (org-prose--make-overlay (nth 0 first) (nth 1 first) 'justify
                                     'display '(space :width (0))))))))

(defun org-prose--refresh-justification ()
  "Justify the body text again in the buffers sharing this buffer's text."
  (with-current-buffer (or (buffer-base-buffer) (current-buffer))
    (when org-prose-mode
      (jit-lock-refontify))))

(defun org-prose--justify-after-org-indent (buffer)
  "Justify BUFFER's text again now that `org-indent-mode' has prefixed it.
It adds the prefixes in the background without telling font lock.
Added to `org-indent-post-buffer-init-functions'."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when org-prose-mode
        (org-prose--refresh-justification)))))

(defun org-prose--justify-after-resize (window)
  "Lay out the preview again if its window WINDOW changed width.
That justifies body text and aligns heading tags again.  Added to
`window-size-change-functions' in preview buffers."
  (when (and (eq window (org-prose--preview-window))
             (not (eql (org-prose--text-area-width window)
                       org-prose--text-width)))
    (setq org-prose--text-width (org-prose--text-area-width window))
    (org-prose--refresh-justification)))

(defun org-prose--note-width (window)
  "Note the width of WINDOW's text area that the preview is laid out for.
If the preview was laid out for another width before, as when the line
numbers widened, lay all of it out again once redisplay is done.
Called by `org-prose--overlay-region'."
  (let ((width (org-prose--text-area-width window)))
    (unless (eql width org-prose--text-width)
      (when org-prose--text-width
        (org-prose--check-width-later))
      (setq org-prose--text-width width))))

(defun org-prose--check-width-later ()
  "Lay out the preview again, after redisplay, if its width changed.
Line numbers, for one, change the width of the text area only once
redisplay shows them."
  (unless (timerp org-prose--width-timer)
    (let ((buffer (current-buffer)))
      (setq org-prose--width-timer
            (run-at-time
             0 nil
             (lambda ()
               (when (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (setq org-prose--width-timer nil)
                   (when-let* ((window (org-prose--preview-window)))
                     (setq org-prose--text-width nil)
                     (org-prose--justify-after-resize window))))))))))

(defun org-prose--update-comment-visibility ()
  "Hide comment lines if in preview and `org-prose-preview-hide-comments'."
  (if (and org-prose-preview-mode org-prose-preview-hide-comments)
      (add-to-invisibility-spec 'org-prose-comment)
    (remove-from-invisibility-spec 'org-prose-comment)))

;;;; Fonts

;; Fonts and heights are those of a graphical frame.  A text terminal's
;; frame has none: the height of its `default' face is 1 and its family
;; "default".  Without a graphical frame, as when a daemon restores a
;; desktop, the fonts of buffers wait for one; see
;; `org-prose--after-make-frame'.

(defun org-prose--graphic-frame ()
  "Return a graphical frame to take fonts and face attributes from, or nil.
That is the selected frame if it is graphical, else another one."
  (seq-find #'display-graphic-p (cons (selected-frame) (frame-list))))

(defun org-prose--body-family (&optional frame)
  "Return the first of `org-prose-body-families' that is installed.
Return nil if none is.  FRAME, by default `org-prose--graphic-frame',
is the frame to look for fonts in."
  (when-let* ((frame (or frame (org-prose--graphic-frame))))
    (seq-find (lambda (family) (find-font (font-spec :family family) frame))
              org-prose-body-families)))

(defun org-prose--body-faces ()
  "Return the faces of body text, as a list for a face property.
Earlier faces take precedence.  They are `org-prose-body' and, below
it, the family from `org-prose--body-family'.  In preview,
`org-prose-preview-body' comes first.  In a preview frame's buffer,
the page face of `org-prose--preview-theme' comes before
`org-prose-body'."
  `(,@(and org-prose-preview-mode '(org-prose-preview-body))
    ,@(and org-prose--preview-theme
           (list (org-prose--theme-face org-prose--preview-theme)))
    org-prose-body
    ,@(when-let* ((family (org-prose--body-family)))
        (list (list :family family)))))

(defun org-prose--update-faces ()
  "Set the fonts and heights of the current buffer's text.
Undo them if `org-prose-mode' is off.  Without a graphical frame, wait
for one."
  (org-prose--unremap-faces)
  (setq org-prose--faces-deferred nil)
  (when org-prose-mode
    (if (org-prose--graphic-frame)
        (org-prose--remap-faces)
      (setq org-prose--faces-deferred t)
      (add-hook 'after-make-frame-functions #'org-prose--after-make-frame)))
  (org-prose--update-heights))

(defun org-prose--after-make-frame (frame)
  "Set the fonts of the buffers that waited for a graphical FRAME.
Added to `after-make-frame-functions'."
  (when (display-graphic-p frame)
    (dolist (buffer (buffer-list))
      (when (buffer-local-value 'org-prose--faces-deferred buffer)
        (with-current-buffer buffer
          (org-prose--update-faces))))))

(defun org-prose--update-all-faces (&rest _)
  "Set the fonts and heights of all buffers in `org-prose-mode' again.
The fonts of themes, frames and faces they derive from may have
changed.  Added to `enable-theme-functions' and
`disable-theme-functions'."
  (dolist (buffer (buffer-list))
    (when (buffer-local-value 'org-prose-mode buffer)
      (with-current-buffer buffer
        (org-prose--update-faces)))))

(defun org-prose--face-family (face frame &optional depth)
  "Return the font family of FACE on FRAME, or nil.
That is its :family, else that of the faces it inherits, other than
`default', whose family is that of body text.  The buffer's face
remapping, as by `mixed-pitch-mode', counts too.  DEPTH counts the
faces inherited so far."
  (let ((depth (or depth 0)))
    (when (< depth 10)
      (or (seq-some
           (lambda (spec)
             (cond
              ((and (consp spec) (keywordp (car spec)))
               (or (plist-get spec :family)
                   (org-prose--inherited-family
                    (plist-get spec :inherit) frame depth)))
              ((and spec (symbolp spec) (not (eq spec face)))
               (org-prose--inherited-family spec frame depth))))
           (let ((remap (cdr (assq face face-remapping-alist))))
             (if (and (consp remap) (not (keywordp (car remap))))
                 remap
               (list remap))))
          (let ((family (face-attribute face :family frame)))
            (and (stringp family) family))
          (org-prose--inherited-family
           (face-attribute face :inherit frame) frame depth)))))

(defun org-prose--inherited-family (inherit frame depth)
  "Return the font family set by the faces of INHERIT on FRAME, or nil.
INHERIT is the value of an :inherit attribute, DEPTH as for
`org-prose--face-family'."
  (seq-some (lambda (face)
              (and (facep face)
                   (not (eq face 'default))
                   (org-prose--face-family face frame (1+ depth))))
            (if (listp inherit) inherit (list inherit))))

(defvar org-prose--family-warned nil
  "Non-nil if `org-prose-mode' said that no body font is installed.")

(defun org-prose--remap-faces ()
  "Set body text in `org-prose-body', keeping markup in the regular font.
Faces that set a font family of their own keep it, see
`org-prose-fixed-faces'."
  (let* ((frame (org-prose--graphic-frame))
         (family (or org-prose-fixed-family
                     (face-attribute 'default :family frame)))
         (foreground (face-attribute 'default :foreground frame))
         ;; Before the remapping below, which sets them all.
         (fixed (seq-remove (lambda (face) (org-prose--face-family face frame))
                            (org-prose--fixed-faces))))
    (unless (or org-prose--family-warned
                (stringp (face-attribute 'org-prose-body :family frame))
                (org-prose--body-family frame))
      (setq org-prose--family-warned t)
      (message "org-prose: None of `org-prose-body-families' is installed, \
body text keeps the default font"))
    ;; Each face gets a single remapping, its specs in order of
    ;; precedence: `face-remap-add-relative' sorts the remappings of a
    ;; face by how many attributes they leave unspecified, so the order
    ;; of separate ones can't be relied on.
    (push (apply #'face-remap-add-relative 'default (org-prose--body-faces))
          org-prose--remap-cookies)
    (push (apply #'face-remap-add-relative 'org-prose-noprose
                 `(,@(org-prose--theme-specs 'org-prose-noprose)
                   (:family ,family
                            ,@(and (stringp foreground)
                                   (list :foreground foreground)))))
          org-prose--remap-cookies)
    (dolist (face (seq-union
                   (org-prose--fixed-faces)
                   (seq-filter #'facep
                               (mapcar #'car (org-prose--theme-overrides)))))
      (when-let* ((specs `(,@(org-prose--theme-specs face)
                           ,@(and (memq face fixed)
                                  `((:family ,family))))))
        (push (apply #'face-remap-add-relative face specs)
              org-prose--remap-cookies)))))

(defun org-prose--unremap-faces ()
  "Undo `org-prose--remap-faces'."
  (mapc #'face-remap-remove-relative org-prose--remap-cookies)
  (setq org-prose--remap-cookies nil))

;; Body text is in the `default' face, so its height is set there, and
;; every other face that should keep its regular height gets it back.
;; The `default' face gets a height relative to the frame's, which
;; `text-scale-mode' scales in turn.  The others get absolute heights:
;; relative ones would multiply where the faces inherit from each other
;; or are combined, as `org-block-end-line' inherits
;; `org-block-begin-line', which inherits `org-meta-line'.  So they are
;; set again when `text-scale-mode' changes the scale.

(defun org-prose--update-heights ()
  "Set body text at `org-prose-body-font-height'.
Headings, markup and noprose entries keep their regular height.  Do
nothing but undo that if `org-prose-mode' is off or
`org-prose-preview-mode' is on, which sets the height of all text."
  (mapc #'face-remap-remove-relative org-prose--height-cookies)
  (setq org-prose--height-cookies nil)
  (when-let* (((and org-prose-mode (not org-prose-preview-mode)))
              (frame (org-prose--graphic-frame)))
    (let ((frame-height (face-attribute 'default :height frame))
          (scale (if (bound-and-true-p text-scale-mode)
                     (expt text-scale-mode-step text-scale-mode-amount)
                   1)))
      (cond
       ((floatp org-prose-body-font-height)
        (push (face-remap-add-relative
               'default :height org-prose-body-font-height)
              org-prose--height-cookies))
       ((integerp frame-height)
        (push (face-remap-add-relative
               'default :height
               (/ (float org-prose-body-font-height) frame-height))
              org-prose--height-cookies)))
      (dolist (face (cons 'org-prose-noprose (org-prose--fixed-faces)))
        (when-let* ((height (face-attribute face :height frame 'default))
                    ((numberp height)))
          (push (face-remap-add-relative
                 face :height (round (* scale height)))
                org-prose--height-cookies))))))

;;;; Curly quotes

(defconst org-prose--straight-quote-types
  '(src-block example-block export-block fixed-width keyword babel-call
    property-drawer node-property latex-environment
    inline-src-block inline-babel-call code verbatim latex-fragment)
  "Org elements and objects in which typed quotes stay straight.")

(defun org-prose--inhibit-electric-quote ()
  "Return non-nil if the quote just typed is in code, not text.
For `electric-quote-inhibit-functions'; see
`org-prose--straight-quote-types'."
  (save-excursion
    (backward-char)
    (let ((context (ignore-errors (org-element-context))))
      (and context
           (org-element-lineage context org-prose--straight-quote-types t)
           t))))

(defun org-prose--set-up-quotes ()
  "Turn typed quotes into curly ones in the current buffer."
  ;; Make ' at the start of a word an opening quote, and curl " too.
  (setq-local electric-quote-context-sensitive t
              electric-quote-replace-double t)
  (add-hook 'electric-quote-inhibit-functions
            #'org-prose--inhibit-electric-quote nil t)
  (unless electric-quote-mode
    (electric-quote-local-mode 1)
    (setq org-prose--electric-quote-enabled t))
  (setq org-prose--quotes-set-up t))

(defun org-prose--tear-down-quotes ()
  "Undo `org-prose--set-up-quotes' in the current buffer."
  (when org-prose--quotes-set-up
    (kill-local-variable 'electric-quote-context-sensitive)
    (kill-local-variable 'electric-quote-replace-double)
    (remove-hook 'electric-quote-inhibit-functions
                 #'org-prose--inhibit-electric-quote t)
    (when org-prose--electric-quote-enabled
      (electric-quote-local-mode -1)
      (setq org-prose--electric-quote-enabled nil))
    (setq org-prose--quotes-set-up nil)))

;;;; Minor modes

(defvar-keymap org-prose-mode-map
  :doc "Keymap for `org-prose-mode'.")

;;;###autoload
(put 'org-prose-mode 'safe-local-eval-function t)

;;;###autoload
(define-minor-mode org-prose-mode
  "Minor mode for writing prose in Org.
Sets entry bodies in `org-prose-body', indents every line of body
text and, if `org-prose-curly-quotes' is non-nil, turns typed quotes
into curly ones.  See `org-prose-preview-mode' for a book-like
reading view."
  :lighter " Prose"
  :group 'org-prose
  (cond
   (org-prose-mode
    (unless (derived-mode-p 'org-mode)
      (setq org-prose-mode nil)
      (user-error "Org mode is required for `org-prose-mode'"))
    (org-prose--update-faces)
    (add-hook 'text-scale-mode-hook #'org-prose--update-heights nil t)
    ;; Modes such as `mixed-pitch-mode' remap `default' too: the
    ;; remapping added last takes precedence.
    (add-hook 'buffer-face-mode-hook #'org-prose--update-faces nil t)
    (add-hook 'enable-theme-functions #'org-prose--update-all-faces)
    (add-hook 'disable-theme-functions #'org-prose--update-all-faces)
    (when (and org-prose-visual-line (not visual-line-mode))
      (visual-line-mode 1)
      (setq org-prose--visual-line-enabled t))
    (when org-prose-curly-quotes
      (org-prose--set-up-quotes))
    (font-lock-add-keywords nil org-prose--font-lock-keywords 'append)
    (add-hook 'after-change-functions #'org-prose--refontify-subtree nil t)
    (jit-lock-register #'org-prose--overlay-region t)
    ;; Run after font lock, as justifying measures the text in its faces.
    (remove-hook 'jit-lock-functions #'org-prose--overlay-region t)
    (add-hook 'jit-lock-functions #'org-prose--overlay-region 90 t)
    (jit-lock-refontify))
   (t
    (org-prose-preview-mode -1)
    (org-prose--update-faces)
    (remove-hook 'text-scale-mode-hook #'org-prose--update-heights t)
    (remove-hook 'buffer-face-mode-hook #'org-prose--update-faces t)
    (when org-prose--visual-line-enabled
      (visual-line-mode -1)
      (setq org-prose--visual-line-enabled nil))
    (org-prose--tear-down-quotes)
    (font-lock-remove-keywords nil org-prose--font-lock-keywords)
    (remove-hook 'after-change-functions #'org-prose--refontify-subtree t)
    (jit-lock-unregister #'org-prose--overlay-region)
    (remove-overlays nil nil 'org-prose 'indent)
    (remove-overlays nil nil 'org-prose 'comment)
    (remove-overlays nil nil 'org-prose 'justify)
    (remove-overlays nil nil 'org-prose 'tags)
    (font-lock-flush))))

(defun org-prose--body-char-width ()
  "Return the average width in pixels of a body character in preview."
  (let ((sample (propertize
                 org-prose--sample-text 'face
                 `((:height ,org-prose-preview-font-height)
                   ,@(org-prose--body-faces)))))
    (/ (float (string-pixel-width sample)) (length sample))))

(defun org-prose--preview-width ()
  "Return the Olivetti body width for `org-prose-preview-width'.
Olivetti counts columns of the frame's default font, scaled by its own
reading of the buffer's default height, so convert from the average
character width of the body text at `org-prose-preview-font-height'."
  (let ((column-width (* (frame-char-width)
                         (/ (olivetti-scale-width 1000) 1000.0))))
    (round (* org-prose-preview-width
              (/ (org-prose--body-char-width) column-width)))))

(defun org-prose--set-preview-width ()
  "Narrow the body to about `org-prose-preview-width' characters."
  (setq olivetti-body-width (org-prose--preview-width))
  (olivetti-set-buffer-windows)
  ;; Lay the text out again: the width or the fonts may have changed,
  ;; and lines are set flush in the preview.
  (org-prose--refresh-justification))

;;;###autoload
(define-minor-mode org-prose-preview-mode
  "Show the buffer like a typeset book page.
Sets the text at `org-prose-preview-font-height' and narrows the
body to about `org-prose-preview-width' characters using Olivetti.
Every line starts at the left edge of the page, whatever the level of
its entry: headings start with their last star."
  :group 'org-prose
  (cond
   (org-prose-preview-mode
    (require 'olivetti)
    (unless org-prose-mode
      (org-prose-mode 1))
    ;; Add `org-prose-preview-body' to the body faces, before setting
    ;; the height, which must take precedence.
    (org-prose--update-faces)
    (setq org-prose--preview-saved
          (list :remap (face-remap-add-relative
                        'default :height org-prose-preview-font-height)
                :olivetti olivetti-mode
                :olivetti-width olivetti-body-width))
    ;; Enable Olivetti before setting the width; its mode hooks may set
    ;; a width of their own.
    (unless olivetti-mode
      (olivetti-mode 1))
    (add-hook 'window-size-change-functions
              #'org-prose--justify-after-resize nil t)
    (add-hook 'display-line-numbers-mode-hook
              #'org-prose--check-width-later nil t)
    (add-hook 'org-indent-post-buffer-init-functions
              #'org-prose--justify-after-org-indent)
    (org-prose--set-preview-width))
   (org-prose--preview-saved
    (let ((saved org-prose--preview-saved))
      (setq org-prose--preview-saved nil
            org-prose--text-width nil)
      (remove-hook 'window-size-change-functions
                   #'org-prose--justify-after-resize t)
      (remove-hook 'display-line-numbers-mode-hook
                   #'org-prose--check-width-later t)
      (remove-overlays nil nil 'org-prose 'flush)
      (remove-overlays nil nil 'org-prose 'lead)
      (remove-overlays nil nil 'org-prose 'justify)
      (remove-overlays nil nil 'org-prose 'tags)
      (face-remap-remove-relative (plist-get saved :remap))
      (org-prose--update-faces)
      (setq olivetti-body-width (plist-get saved :olivetti-width))
      (if (plist-get saved :olivetti)
          (olivetti-set-buffer-windows)
        (olivetti-mode -1)))))
  (if org-prose-preview-mode
      (add-to-invisibility-spec 'org-prose-lead)
    (remove-from-invisibility-spec 'org-prose-lead))
  (org-prose--update-comment-visibility))

;;;###autoload
(defun org-prose-toggle-preview ()
  "Toggle `org-prose-preview-mode'."
  (interactive)
  (org-prose-preview-mode 'toggle))

;;;###autoload
(defun org-prose-preview-toggle-comments ()
  "Toggle whether comment lines are hidden in preview in this buffer."
  (interactive)
  (setq-local org-prose-preview-hide-comments
              (not org-prose-preview-hide-comments))
  (org-prose--update-comment-visibility)
  (message "Comments %s in preview"
           (if org-prose-preview-hide-comments "hidden" "shown")))

;;;; Preview frame

(defun org-prose--theme-face (theme &optional role)
  "Return the face of THEME for ROLE, nil (the page), `heading' or `fixed'."
  (intern (format "org-prose-preview-%s%s" theme
                  (if role (format "-%s" role) ""))))

(defun org-prose--theme-overrides ()
  "Return the attributes set by the page of `org-prose--preview-theme'.
They are for faces that the Emacs theme gives a color of its own that
must match the page, as a list of (FACE . PLIST).  Return nil if the
buffer is not a preview frame's."
  (when-let* ((theme org-prose--preview-theme)
              (bg (face-background (org-prose--theme-face theme))))
    `((fringe :background ,bg)
      (hl-line :background ,bg)
      (org-block :background ,bg)
      (org-block-begin-line :background ,bg)
      (org-block-end-line :background ,bg)
      ;; Hidden leading stars, and the stars `org-indent-mode'
      ;; prefixes lines with, must be the color of the page.
      ;; `org-indent' inherits `org-hide', but is a fixed face and so
      ;; has a color of its own.
      (org-hide :foreground ,bg)
      (org-indent :foreground ,bg)
      (region :background
              ,(if (eq theme 'light)
                   (color-darken-name bg 12)
                 (color-lighten-name bg 15))))))

(defun org-prose--theme-specs (face)
  "Return the specs `org-prose--preview-theme' gives FACE, or nil.
They are a list for a face property, earlier specs taking precedence:
the attributes of `org-prose--theme-overrides', then the theme's
heading face for headings, and its fixed face for the other fixed
faces and `org-prose-noprose'.  Body text, the `default' face, gets
the page face from `org-prose--body-faces' instead."
  (when-let* ((theme org-prose--preview-theme))
    (let ((override (alist-get face (org-prose--theme-overrides)))
          (role (cond
                 ((memq face (org-prose--heading-faces))
                  (org-prose--theme-face theme 'heading))
                 ((or (eq face 'org-prose-noprose)
                      (memq face (org-prose--fixed-faces)))
                  (org-prose--theme-face theme 'fixed)))))
      (delq nil (list override role)))))

(defun org-prose--style-frame (frame theme)
  "Give FRAME the background mode and page colors of THEME.
These are what the face remappings in its buffer can't change: the
cursor, and the faces of other buffers such as the minibuffer."
  (let ((page (org-prose--theme-face theme))
        (frame-background-mode theme))
    (when-let* ((bg (face-background page)))
      (set-face-background 'default bg frame))
    (when-let* ((fg (face-foreground page)))
      (set-face-foreground 'default fg frame))
    ;; Face specs that depend on the background, such as that of
    ;; `org-prose-preview-body', should match the page.
    (frame-set-background-mode frame)
    (when org-prose-preview-frame-ignore-theme
      (org-prose--reset-frame-faces frame))
    ;; The cursor has the color of body text.
    (when-let* ((fg (or (face-foreground 'org-prose-preview-body frame)
                        (face-foreground page))))
      (set-frame-parameter frame 'cursor-color fg))))

(defconst org-prose--font-attributes
  '(:family :foundry :width :height :weight :slant)
  "Face attributes that `org-prose--reset-frame-faces' keeps.")

(defun org-prose--reset-frame-faces (frame)
  "Give the faces of FRAME their colors without the Emacs theme.
Each face gets the attributes of its `defface' spec for the background
mode of FRAME, and those you set with Customize on top.  Its font, as
the theme and your settings make it, is kept.  The `default' face and
the faces of org-prose are left alone."
  (dolist (face (face-list))
    (unless (or (eq face 'default)
                (string-prefix-p "org-prose-" (symbol-name face)))
      (condition-case nil
          (let ((font (mapcan (lambda (attribute)
                                (let ((value (face-attribute
                                              face attribute frame)))
                                  (unless (eq value 'unspecified)
                                    (list attribute value))))
                              org-prose--font-attributes))
                (user (cadr (assq 'user (get face 'theme-face)))))
            (face-spec-reset-face face frame)
            (face-spec-set-2 face frame
                             (face-spec-choose (face-default-spec face) frame))
            (when user
              (face-spec-set-2 face frame (face-spec-choose user frame)))
            (when font
              (apply #'set-face-attribute face frame font)))
        ;; As when making a frame, don't let an invalid spec stop it.
        (error nil)))))

(defun org-prose--restyle-preview-frames (&rest _)
  "Style the preview frames again after a theme reset their faces.
Added to `enable-theme-functions' and `disable-theme-functions'."
  (dolist (frame (frame-list))
    (let ((buf (frame-parameter frame 'org-prose-preview)))
      (when (buffer-live-p buf)
        (org-prose--style-frame
         frame (buffer-local-value 'org-prose--preview-theme buf))))))

(defun org-prose--preview-frame (buffer)
  "Return the frame previewing BUFFER, or nil.
BUFFER is a preview frame's buffer, or that buffer's base buffer."
  (seq-find (lambda (frame)
              (let ((buf (frame-parameter frame 'org-prose-preview)))
                (and (buffer-live-p buf)
                     (memq buffer (list buf (buffer-base-buffer buf))))))
            (frame-list)))

(defun org-prose--preview-buffer-killed ()
  "Delete the frame of the preview buffer being killed.
Added to `kill-buffer-hook' in preview buffers."
  (when-let* ((frame (org-prose--preview-frame (current-buffer))))
    (set-frame-parameter frame 'org-prose-preview nil)
    ;; It fails if this is the only frame, which can then stay.
    (ignore-errors (delete-frame frame))))

(defun org-prose--preview-frame-deleted (frame)
  "Kill the buffer of FRAME if it is a preview frame.
Added to `delete-frame-functions'."
  (let ((buf (frame-parameter frame 'org-prose-preview)))
    (when (buffer-live-p buf)
      (set-frame-parameter frame 'org-prose-preview nil)
      (kill-buffer buf))))

;; jit-lock refuses to run in indirect buffers: the `fontified' text
;; property, which tells it what is done, is shared with the base
;; buffer.  So a preview buffer has its base buffer fontify the text it
;; shows and refontify the text changed in it.  That also updates the
;; preview buffer's overlays, see `org-prose--overlay-region'.

(defun org-prose--fontify-in-base (pos)
  "Have the base buffer fontify the text from POS.
Added to `fontification-functions' in preview buffers."
  (with-current-buffer (buffer-base-buffer)
    (jit-lock-fontify-now pos (min (point-max) (+ pos jit-lock-chunk-size)))))

(defun org-prose--refontify-in-base (beg end old-len)
  "Have the base buffer refontify the text changed between BEG and END.
OLD-LEN is the length of the text replaced.  Added to
`after-change-functions' in preview buffers."
  (with-current-buffer (buffer-base-buffer)
    (jit-lock-after-change beg end old-len)))

(defun org-prose--make-preview-buffer (base)
  "Return a new indirect buffer of BASE in `org-prose-mode'.
BASE must be in `org-prose-mode'."
  (let ((buf (make-indirect-buffer
              base (generate-new-buffer-name
                    (format "%s<preview>" (buffer-name base))))))
    (with-current-buffer buf
      ;; Font lock's and `org-prose-mode''s complaints that jit-lock
      ;; doesn't work here are answered below.
      (let ((org-inhibit-startup-visibility-stuff t)
            (inhibit-message t)
            (message-log-max nil))
        (org-mode)
        (unless org-prose-mode
          (org-prose-mode 1)))
      ;; Fold what is folded in the base buffer.  Folds belong to each
      ;; buffer, so from now on they change in each on its own.
      (pcase-dolist (`(,from ,to ,spec)
                     (with-current-buffer base (org-fold-core-get-regions)))
        (org-fold-core-region from to t spec))
      (add-hook 'fontification-functions #'org-prose--fontify-in-base nil t)
      (add-hook 'after-change-functions #'org-prose--refontify-in-base nil t)
      (add-hook 'kill-buffer-hook #'org-prose--preview-buffer-killed nil t))
    buf))

;;;###autoload
(defun org-prose-preview-frame (&optional theme)
  "Show the buffer in `org-prose-preview-mode' in a frame of its own.
THEME, `light' or `dark', sets the colors and fonts of the frame.
Interactively, it is `org-prose-preview-frame-theme', or read with
a prefix argument.

The frame shows an indirect buffer, so edits in either buffer appear
in both.  It starts with what is folded in the buffer folded too.  If
the buffer already has a preview frame, select it and
set it in THEME.  Deleting the frame kills its buffer, and killing
the buffer deletes the frame."
  (interactive
   (list (if current-prefix-arg
             (intern (completing-read "Theme: " '("light" "dark") nil t))
           org-prose-preview-frame-theme)))
  (unless (derived-mode-p 'org-mode)
    (user-error "Org mode is required for `org-prose-preview-frame'"))
  (with-current-buffer (or (buffer-base-buffer) (current-buffer))
    (unless org-prose-mode
      (org-prose-mode 1)))
  (let* ((base (or (buffer-base-buffer) (current-buffer)))
         (frame (org-prose--preview-frame base))
         (buf (if frame
                  (frame-parameter frame 'org-prose-preview)
                (org-prose--make-preview-buffer base))))
    (with-current-buffer buf
      (setq org-prose--preview-theme (or theme org-prose-preview-frame-theme))
      (org-prose--update-faces)
      (unless frame
        (setq frame (make-frame
                     `(,@org-prose-preview-frame-parameters
                       (name . ,(format "Preview: %s" (buffer-name base)))
                       (width . ,org-prose-preview-frame-width)
                       (fullscreen . fullheight))))
        (set-frame-parameter frame 'org-prose-preview buf)
        (set-window-buffer (frame-selected-window frame) buf)
        (add-hook 'delete-frame-functions #'org-prose--preview-frame-deleted)
        (add-hook 'enable-theme-functions #'org-prose--restyle-preview-frames)
        (add-hook 'disable-theme-functions #'org-prose--restyle-preview-frames))
      (org-prose--style-frame frame org-prose--preview-theme)
      ;; Measure the width in the frame that shows the page.
      (with-selected-frame frame
        (if org-prose-preview-mode
            (org-prose--set-preview-width)
          (org-prose-preview-mode 1))))
    (select-frame-set-input-focus frame)))

(provide 'org-prose)
;;; org-prose.el ends here
