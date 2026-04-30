;;; build-resume.el --- Build tailored resumes from org to PDF -*- lexical-binding: t; -*-
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
;; This script builds a tailored resume from an org file to PDF using the 'resume' LaTeX class.
;; It handles the LaTeX configuration and export settings.
;;
;; Usage:
;; - Run `M-x build-resume` to generate the resume
;; - Output will be saved next to resume.org (or to adithya-resume-output-directory)

;;; Code:
(require 'cl-lib)
(require 'ox-latex)

(defgroup adithya-resume nil
  "Settings for CV building."
  :group 'org-export)

(defcustom adithya-resume-output-directory nil
  "Directory where the CV PDF will be saved."
  :type 'string
  :group 'adithya-resume)

(defcustom adithya-resume-input-file "resume.org"
  "The org file containing the CV content."
  :type 'string
  :group 'adithya-resume)

(defcustom adithya-resume-output-filename "resume.pdf"
  "Name of the output PDF file."
  :type 'string
  :group 'adithya/cv)

(defun adithya-resume--setup-latex-class ()
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
    GitHub - \\href{https://github.com/libdist-rs}{https://github.com/libdist-rs}
}
\\address{
    \\\\ Website - \\href{https://adithyabhatkajake.github.io}{https://adithyabhatkajake.github.io}
}
\\address{Visa Research, Visa Inc., CA} % Your address
"
                 ("\\begin{rSection}{%s}" "\\end{rSection}" "\\begin{rSection}{%s}" "\\end{rSection}")
                 ("\\begin{rSubsection}{%s}" "\\end{rSubsection}" "\\begin{rSubsection}{%s}" "\\end{rSubsection}"))))


(defun adithya-resume--setup-export-settings ()
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

(defun adithya-resume--ensure-output-directory ()
  "Ensure the output directory exists."
  (unless (file-exists-p adithya-resume-output-directory)
    (make-directory adithya-resume-output-directory t)))

;;;###autoload
(defun build-adithya-resume ()
  "Generate the CV from the org file."
  (interactive)
  (adithya-resume--setup-latex-class)
  (adithya-resume--setup-export-settings)
  (adithya-resume--ensure-output-directory)

  (let* ((output-dir (or adithya-resume-output-directory
                      (file-name-directory (expand-file-name adithya-resume-input-file))))
         (output-path (expand-file-name
                      adithya-resume-output-filename
                      output-dir)))
    (with-current-buffer (find-file-noselect adithya-resume-input-file)
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
                              (concat (file-name-sans-extension adithya-resume-input-file) ".pdf"))))
          (when (and (file-exists-p generated-pdf)
                     (not (string= generated-pdf output-path)))
            (rename-file generated-pdf output-path t)))))
    (message "CV built successfully: %s" output-path)))

;; For command-line usage
(when noninteractive
  (build-adithya-resume))

(provide 'adithya-resume)
;;; adithya-resume.el ends here
