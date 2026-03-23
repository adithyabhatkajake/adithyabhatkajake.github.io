;; --- How to build our website -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2023 Adithya Bhat
;;
;; Author: Adithya Bhat <dth.bht@gmail.com>
;; Maintainer: Adithya Bhat <dth.bht@gmail.com>
;; Created: April 15, 2023
;; Modified: October 18, 2024
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;;
;; This file is not part of GNU Emacs.
;;; Commentary:
;; In this file, we will do the following:
;;

;;; Code:

;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.
(require 'package)

;; Code: Set the package installation directory to a local folder
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

;; Initialize the package system
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; Install dependencies
(package-install 'htmlize)
(package-install 'ox-tufte)

;; Load the org-mode library
(require 'org)
(require 'ox-publish)
(require 'ol)
(require 'org-attach)

;; Build CV PDF into assets/
(load-file "build-adithya-cv.el")
(build-adithya-cv)

;; Define the root index file
(defvar root-index-file "index.org")
(defvar root-about-file "about.org")
(defvar publish-dir "build")
(defvar assets-dir "assets")
(defvar site-root "/")  ;; Change to your base URL if needed

;; Create publish directory if it doesn't exist
(unless (file-exists-p publish-dir)
  (make-directory publish-dir t))

;; Ensure that the assets directory exists
;; If it doesn't, warn the user and fail
(unless (file-exists-p assets-dir)
  (message "Assets directory not found. Please create one.")
  (error "Assets directory not found"))

;; Ensure that the root index file exists
;; If it doesn't, warn the user and fail
(unless (file-exists-p root-index-file)
  (message "Root index file not found. Please create one.")
  (error "Root index file not found"))

;; Ensure that the about file exists
;; If it doesn't, warn the user and fail
(unless (file-exists-p root-about-file)
  (message "About file not found. Please create one.")
  (error "About file not found"))

;; Org export settings
(setq org-export-with-properties nil ;; This disables property export globally
      org-export-with-tags nil ;; This disables tag export globally
      ;; Global attach settings
      org-attach-id-dir (file-name-concat assets-dir "attachments/") ;; Attachments directory
      org-id-locations-file (expand-file-name ".org-id-locations" default-directory) ;; ID locations file
      org-attach-use-inheritance t
      ;; Use CSS classes for syntax highlighting instead of inline styles
      org-html-htmlize-output-type 'css)

;; Create a standard HTML nav using absolute paths from site root
(defun site-nav-html (_)
  "Return a standard HTML nav with links to the home and blog pages."
  (format "
<div class=\"banner\">
   <a id=\"myname\" href=\"%s\">Hermitsage</a>
  <hr>
<nav>
    <p>
        <a href=\"%s\">Home</a>
        <a href=\"%sabout.html\">About</a>
        <a href=\"%scv.html\">CV</a>
        <a href=\"%sblogs/index.html\">Blog</a>
    </p>
  </nav>
</div>" site-root site-root site-root site-root site-root))

;; --- Blog index generation ---
(defvar blogs-dir "blogs")
(defvar blogs-per-page 10)

(defun blog--extract-metadata (file)
  "Extract title and date from an org FILE's headers."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((title (when (re-search-forward "^#\\+title:\\s-*\\(.*\\)" nil t)
                   (match-string 1)))
          (date (progn
                  (goto-char (point-min))
                  (when (re-search-forward "^#\\+date:\\s-*<\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t)
                    (match-string 1)))))
      (when (and title date)
        (list :title title :date date :file (file-name-nondirectory file))))))

(defun blog--generate-page (entries page-num total-pages output-dir)
  "Generate a single blog index page with ENTRIES for PAGE-NUM of TOTAL-PAGES."
  (let* ((filename (if (= page-num 1) "index.org"
                     (format "page-%d.org" page-num)))
         (filepath (file-name-concat output-dir filename)))
    (with-temp-file filepath
      (insert "#+title: Blog\n\n")
      (dolist (entry entries)
        (let ((title (plist-get entry :title))
              (date (plist-get entry :date))
              (file (plist-get entry :file)))
          (insert (format "- [[file:%s][%s]] — /%s/\n" file title date))))
      ;; Pagination nav
      (when (> total-pages 1)
        (insert "\n@@html:<nav class=\"pagination\">@@\n")
        (when (> page-num 1)
          (let ((prev-file (if (= page-num 2) "index.html" (format "page-%d.html" (1- page-num)))))
            (insert (format "[[file:%s][← Newer]]" prev-file))))
        (when (and (> page-num 1) (< page-num total-pages))
          (insert " | "))
        (when (< page-num total-pages)
          (insert (format "[[file:page-%d.html][Older →]]" (1+ page-num))))
        (insert "\n@@html:</nav>@@\n")))
    (message "Generated blog index: %s" filepath)))

(defun generate-blog-index ()
  "Scan blogs/ for org files, generate paginated index pages."
  (let* ((blog-path (file-name-concat default-directory blogs-dir))
         (org-files (directory-files blog-path t "\\.org$"))
         ;; Exclude generated index/page files
         (org-files (seq-remove
                     (lambda (f)
                       (let ((name (file-name-nondirectory f)))
                         (or (string= name "index.org")
                             (string-match-p "^page-[0-9]+\\.org$" name))))
                     org-files))
         ;; Extract metadata from each file
         (entries (delq nil (mapcar #'blog--extract-metadata org-files)))
         ;; Sort by date descending
         (entries (sort entries
                        (lambda (a b)
                          (string> (plist-get a :date) (plist-get b :date)))))
         (total (length entries))
         (total-pages (max 1 (ceiling (/ (float total) blogs-per-page)))))
    ;; Clean old generated index files
    (dolist (f (directory-files blog-path t "^\\(index\\|page-[0-9]+\\)\\.org$"))
      (delete-file f))
    ;; Generate each page
    (dotimes (i total-pages)
      (let* ((start (* i blogs-per-page))
             (end (min (* (1+ i) blogs-per-page) total))
             (page-entries (seq-subseq entries start end)))
        (blog--generate-page page-entries (1+ i) total-pages blog-path)))
    (message "Blog index generated: %d posts across %d pages" total total-pages)))

;; Generate blog index before publishing
(when (file-directory-p blogs-dir)
  (generate-blog-index))

;; We are using https://ogbe.net/blog/emacs_org_static_site for inspiration
;; Configure attachment directories

;; Fix attachment links during export
(defun fix-attachment-links (link desc info)
  "Handle attachment links properly during export.
Ensures LINK with DESC is properly resolved using INFO."
  (let ((path (org-element-property :path link)))
    (if (string-prefix-p "attachment:" (org-element-property :raw-link link))
        (let ((filename (substring path (length "attachment:")))
              (html-extension (plist-get info :html-extension))
              (link-org-files-as-html-p (org-html-link-org-files-as-html-p info)))
          (format "<a href=\"%s/%s\">%s</a>"
                  attach-dir
                  filename
                  (or desc filename)))
      nil)))

;; Register the fix-attachment-links function
(org-link-set-parameters "attachment"
                         :export #'fix-attachment-links)

(defun html-head-fn ()
  "Return HTML head elements for my Org HTML export."
  (concat
   "<link rel=\"stylesheet\" type=\"text/css\" href=\"/assets/tufte-css/tufte.css\" />\n"
   "<link rel=\"stylesheet\" href=\"/assets/tufte-css/ox-tufte.css\" type=\"text/css\" />\n"
   "<link rel=\"stylesheet\" href=\"/assets/syntax.css\" type=\"text/css\" />\n"))

;; Set up the org-publish project for the root index file.
(setq org-publish-project-alist
      ;; Publish the root index file
      `(("index-project"
         :base-directory ,default-directory
         :base-extension "org"
         :publishing-directory ,publish-dir
         :publishing-function org-html-publish-to-html
         :recursive nil
         :publishing-files (list ,root-index-file ,root-about-file)
         :html-head ,(html-head-fn)
         :section-numbers nil
         :html-preamble site-nav-html
         :html-postamble nil
         :with-toc nil)

        ;; Publish the blogs directory
        ("blogs-project"
         :base-directory ,(file-name-concat default-directory "blogs")
         :base-extension "org"
         :publishing-directory ,(file-name-concat publish-dir "blogs")
         :publishing-function org-html-publish-to-html
         :recursive nil
         :html-head ,(html-head-fn)
         :section-numbers nil
         :html-preamble site-nav-html
         :html-postamble nil
         :with-toc nil)

        ;; Publish the assets directory
        ("assets-project"
         :base-directory ,assets-dir
         :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|ttf\\|woff\\|eot\\|svg"
         :publishing-directory ,(file-name-concat publish-dir assets-dir)
         :recursive t
         :publishing-function org-publish-attachment)))

(org-publish-all t)

(message "Build complete!")
;;; build.el ends here
