;;; build-cv.el --- Build CV from org to PDF -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Adithya Bhat
;;
;; Author: Adithya Bhat <dth.bht@gmail.com>
;; Maintainer: Adithya Bhat <dth.bht@gmail.com>
;; Created: April 06, 2025
;; Version: 0.0.1
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; This script builds a CV from an org file to PDF using the 'resume' LaTeX class.
;; It handles the LaTeX configuration and export settings.
;;
;; Usage:
;; - Run `M-x build-cv` to generate the CV
;; - Output will be saved to assets/cv.pdf

;;; Code:
(require 'cl-lib)
(require 'ox-latex)

(defgroup adithya-cv nil
  "Settings for CV building."
  :group 'org-export)

(defcustom adithya-cv-output-directory "./assets/"
  "Directory where the CV PDF will be saved."
  :type 'string
  :group 'adithya-cv)

(defcustom adithya-cv-input-file "CV.org"
  "The org file containing the CV content."
  :type 'string
  :group 'adithya-cv)

(defcustom adithya-cv-output-filename "cv.pdf"
  "Name of the output PDF file."
  :type 'string
  :group 'adithya/cv)

(defun adithya-cv--setup-latex-class ()
  "Configure the LaTeX resume class for the CV."
  (add-to-list 'org-latex-classes
               '("resume" "\\documentclass{resume}

% Change the page layout if you need to
[PACKAGES]
[EXTRA]
\\newcommand{\\tab}[1]{\\hspace{.2667\\textwidth}\\rlap{#1}}
\\newcommand{\\itab}[1]{\\hspace{0em}\\rlap{#1}}
\\name{Adithya Bhat} % Your name
\\address{
    \\\\ Email - \\href{mailto:dth.bht@gmail.com}{dth.bht@gmail.com} \\\\
    GitHub - \\href{https://github.com/adithyabhatkajake}{https://github.com/adithyabhatkajake}
}
\\address{
    \\\\ Website - \\href{https://adithyabhatkajake.github.io}{https://adithyabhatkajake.github.io}
}
\\address{Visa Research, Visa Inc., CA} % Your address
"
                 ("\\begin{rSection}{%s}" "\\end{rSection}" "\\begin{rSection}{%s}" "\\end{rSection}")
                 ("\\begin{rSubsection}{%s}" "\\end{rSubsection}" "\\begin{rSubsection}{%s}" "\\end{rSubsection}"))))


(defun adithya-cv--setup-export-settings ()
  "Configure the export settings for the CV."
  (setq org-latex-logfiles-extensions
        '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm" "vrb"
          "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl"
          "xmpi" "run.xml" "bcf"))
  (setq org-latex-packages-alist nil)
  (setq org-latex-default-packages-alist nil)

  ;; Add your specific LaTeX packages
  (add-to-list 'org-latex-packages-alist '("utf8" "inputenc"))
  (add-to-list 'org-latex-packages-alist
               '("left=0.60in,top=0.95in,right=0.60in,bottom=0.95in" "geometry" nil))
  (add-to-list 'org-latex-packages-alist
               '("colorlinks=true,allcolors=cyan" "hyperref" nil))
  (add-to-list 'org-latex-packages-alist '("" "breakurl" nil))

  (setq org-export-exclude-tags '("noexport" "ignore")))

(defun adithya-cv--ensure-output-directory ()
  "Ensure the output directory exists."
  (unless (file-exists-p adithya-cv-output-directory)
    (make-directory adithya-cv-output-directory t)))

;;;###autoload
(defun build-adithya-cv ()
  "Generate the CV from the org file."
  (interactive)
  (adithya-cv--setup-latex-class)
  (adithya-cv--setup-export-settings)
  (adithya-cv--ensure-output-directory)

  (let ((output-path (expand-file-name
                      adithya-cv-output-filename
                      adithya-cv-output-directory)))
    (with-current-buffer (find-file-noselect adithya-cv-input-file)
      ;; Export to PDF
      (let ((org-export-with-local-variables t)
            (org-latex-default-class "resume")
            ;; These correspond to #+OPTIONS: toc:nil title:nil date:nil
            (org-export-with-toc nil)
            (org-export-with-title nil)
            (org-export-with-date nil))
        (org-latex-export-to-pdf)
        ;; Move the PDF from source directory to output directory
        (let ((generated-pdf (expand-file-name
                              (concat (file-name-sans-extension adithya-cv-input-file) ".pdf"))))
          (when (and (file-exists-p generated-pdf)
                     (not (string= generated-pdf output-path)))
            (rename-file generated-pdf output-path t)))))
    (message "CV built successfully: %s" output-path)))

;; For command-line usage
(when noninteractive
  (build-adithya-cv))

(provide 'adithya-cv)
;;; adithya-cv.el ends here
