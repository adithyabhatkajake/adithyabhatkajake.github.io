;;; build.el --- How to build our website -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2023 Adithya Bhat
;;
;; Author: Adithya Bhat <dth.bht@gmail.com>
;; Maintainer: Adithya Bhat <dth.bht@gmail.com>
;; Created: April 15, 2023
;; Modified: April 15, 2023
;; Version: 0.0.1
;; Package-Requires: ((emacs "28.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  How to build our website
;;
;;; Code:

(require 'ox-publish)

;; Setup usage of htmlize
;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.
(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

;; Initialize the package system
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; Install dependencies
(package-install 'htmlize)

;; Remove the validate link at the bottom
(setq org-html-validation-link nil)

;; Ignore all the org headings with tags: noexport and ignore
(setq org-export-exclude-tags '("noexport" "ignore"))

;; This tells org export how to handle exporting code blocks
;; By choosing css, we can let an external css file handle the syntax highlighting
(setq org-html-htmlize-output-type 'css)

;; This settings sets the header of the html file
;; We add our doom light themed css file to the head of the html file here.
;; We also add the mathjax script to the head of the html file here.
(setq org-html-head (concat "<link rel=\"stylesheet\" href=\"/assets/styles.css\"/>\n"
                            "<script type=\"text/javascript\" id=\"MathJax-script\" async src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js\"></script>"))

(defvar build-website-root default-directory
  "The folder where the website source files are stored.")

(defvar build-website-output (expand-file-name "_site" build-website-root)
  "The folder where the website will be built.")

(message "Building website in %s" build-website-output)

(defvar build-website-exclude-dirs '("_site" ;; Output folder
                                     ".git"  ;; Version control
                                     "assets";; Assets folder
                                     )
  "The folders to exclude when building the website.")

;; Ensure Emacs uses UTF-8 encoding by default
(prefer-coding-system 'utf-8)
;; (setq default-buffer-file-coding-system 'utf-8)
(setq coding-system-for-read 'utf-8)
(setq coding-system-for-write 'utf-8)
(setq org-export-coding-system 'utf-8)

;; Generate the CV from CV.org
(add-to-list 'org-latex-classes
             '("resume" "\\documentclass{resume}

% Change the page layout if you need to
[PACKAGES]
[EXTRA]
\\newcommand{\\tab}[1]{\\hspace{.2667\\textwidth}\\rlap{#1}}
\\newcommand{\\itab}[1]{\\hspace{0em}\\rlap{#1}}
\\name{Adithya Bhat} % Your name
\\address{
    \\\\ Email - \\href{mailto:aditbhat@visa.com}{aditbhat@visa.com} \\\\
    GitHub - \\href{https://github.com/adithyabhatkajake}{https://github.com/adithyabhatkajake}
}
\\address{
    \\\\ Website - \\href{https://adithyabhatkajake.github.io}{https://adithyabhatkajake.github.io}
}
\\address{Visa Research, Visa Inc., CA} % Your address
"
               ("\\begin{rSection}{%s}" "\\end{rSection}" "\\begin{rSection}{%s}" "\\end{rSection}")
               ("\\begin{rSubsection}{%s}" "\\end{rSubsection}" "\\begin{rSubsection}{%s}" "\\end{rSubsection}")))

;; TODO: Generate CV fresh every time
(defun build-generate-cv ()
  "Generate the CV from the org file."
  (let ((org-latex-logfiles-extensions (quote ("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm" "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "xmpi" "run.xml" "bcf")))
        (org-latex-packages-alist 'nil)
        (org-latex-default-packages-alist 'nil))
    (with-current-buffer (find-file-noselect "CV.org")
      (org-latex-export-to-pdf))))

;; Generate the CV every time
(build-generate-cv)

;; Create a nav.org file with links to the following:
;; - Home
;; - CV
;; - All directories in the root folder
(defun build-generate-nav-org (exclude-dirs)
  "Generate a `nav.org` file with links.
The links include the base directory and all subdirectories, except those in
EXCLUDE-DIRS."
  (let* ((base-dir default-directory)
         (all-dirs (directory-files base-dir t "^[^.]" t))
         (filtered-dirs (cl-remove-if
                         (lambda (dir)
                           (or (not (file-directory-p dir))
                               (member (file-name-nondirectory dir) exclude-dirs)))
                         all-dirs))
         (assets-dir (expand-file-name "assets" base-dir))
         (nav-file (expand-file-name "nav.org" assets-dir)))
    (with-temp-file nav-file
      (insert "*Links*: @@html:")
      (insert "<a href=\"/\">Home</a> ")
      (insert "<a href=\"/CV.html\">CV</a>")
      (dolist (dir filtered-dirs)
        (let ((dir-name (file-name-nondirectory dir)))
          (insert (format " <a href=\"/%s\">%s</a>" dir-name dir-name))))
      (insert "@@\n"))))

;; Generate the nav.org file
(build-generate-nav-org build-website-exclude-dirs)

;; Read the nav.org file
(defun build-read-nav-org ()
  "Read the content of `nav.org` from the `assets` directory."
  (let* ((base-dir default-directory)
         (nav-file (expand-file-name "assets/nav.org" base-dir)))
    (if (file-exists-p nav-file)
        (with-temp-buffer
          (insert-file-contents nav-file)
          (buffer-string))
      (message "nav.org not found in assets directory.")
      "")))

;; Inject nav.org to the top of all generated html files
(defun build-org-html-publish-to-html (plist filename pub-dir)
  "Publish an Org file to HTML, including `nav.org` at the top.
PLIST is the property list for the project. FILENAME is the filename of the
Org file to publish. PUB-DIR is the publishing directory."
  (let ((nav-content (build-read-nav-org))
        (pub-dir (expand-file-name pub-dir)))
    (unless (file-directory-p pub-dir)
      (make-directory pub-dir t))
    (with-current-buffer (find-file-noselect filename)
      (goto-char (point-min))
      (insert nav-content "\n")
      (org-publish-org-to 'html filename
                          (concat "." (or (plist-get plist :html-extension) "html"))
                          plist pub-dir))))

;; A function to list all directories to export from the root directory
(defun build-list-org-directories (exclude-dirs)
  "List all directories in `default-directory` except those in EXCLUDE-DIRS."
  (let ((all-dirs (directory-files default-directory t "^[^.]" t))
        (filtered-dirs '()))
    (dolist (dir all-dirs)
      (when (and (file-directory-p dir)
                 (not (member (file-name-nondirectory dir) exclude-dirs)))
        (push dir filtered-dirs)))
    filtered-dirs))

;; A function to generate the org-publish project alist
(defun build-generate-org-publish-projects (exclude-dirs)
  "Generate org-publish project alist entries.
It creates entries for all directories in `default-directory` except excluded
ones in EXCLUDE-DIRS."
  (let ((org-dirs (build-list-org-directories exclude-dirs))
        (projects '()))
    ;; Add the base directory
    (push (list "site:base"
                :base-directory default-directory
                :publishing-directory build-website-output
                :publishing-function 'build-org-html-publish-to-html
                :section-numbers nil
                :with-toc nil)
          projects)
    (dolist (dir org-dirs)
      (let ((project-name (file-name-nondirectory dir)))
        (message "Processing %s with dir %s" project-name dir)
        (push (list project-name
                    :base-directory dir
                    :publishing-directory (file-name-concat build-website-output project-name)
                    :publishing-function 'build-org-html-publish-to-html
                    :section-numbers nil
                    :with-toc nil)
              projects)))
    ;; Add assets directory
    (push `("assets"
            :base-directory ,(file-name-concat default-directory "assets")
            :recursive t
            :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|pptx"
            :publishing-directory ,(file-name-concat build-website-output "assets")
            :publishing-function org-publish-attachment)
          projects)
    (setq org-publish-project-alist projects)))

;; Generate the project alist
(build-generate-org-publish-projects build-website-exclude-dirs)

;; A function to build all projects in org-publish-project-alist
(defun build-publish-all-projects ()
  "Publish all projects in org-publish-project-alist."
  (interactive)
  (dolist (project org-publish-project-alist)
    (org-publish-project (car project) t)))

;; Generate the site output
(build-publish-all-projects)

(message "Build complete!")
(provide 'build)
;;; build.el ends here
