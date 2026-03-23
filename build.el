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
(package-refresh-contents)

;; Install dependencies
(package-install 'htmlize)
(package-install 'ox-tufte)
(package-install 'rust-mode)
(package-install 'citeproc)

;; Load the org-mode library
(require 'org)
(require 'ox-publish)
(require 'ol)
(require 'org-attach)
(require 'oc)
(require 'oc-csl)
(require 'citeproc)

;; Allow alphabetical list markers (a. b. c.) for nested sub-items
(setq org-list-allow-alphabetical t)

;; Configure org-cite with bibliography from citar config (passed via build.sh)
(setq org-cite-global-bibliography (list (getenv "BIBLIOGRAPHY")))
(setq org-cite-export-processors
      `((html csl ,(expand-file-name "assets/rich-inline.csl" default-directory))
        (t basic)))

;; --- Content-hash build cache ---

(defvar hash-cache-file (expand-file-name ".build-hashes" default-directory)
  "File storing content hashes from the previous build.")

(defvar hash-cache-old (make-hash-table :test 'equal)
  "Hash table of file -> sha256 from the previous build.")

(defvar hash-cache-new (make-hash-table :test 'equal)
  "Hash table of file -> sha256 being built during this run.")

(defvar force-full-rebuild (string= (or (getenv "FORCE_BUILD") "0") "1")
  "When non-nil, rebuild everything regardless of cache.")

(defun hash-cache-load ()
  "Load the hash cache from disk into `hash-cache-old'."
  (when (file-exists-p hash-cache-file)
    (with-temp-buffer
      (insert-file-contents hash-cache-file)
      (let ((data (read (current-buffer))))
        (setq hash-cache-old (make-hash-table :test 'equal))
        (dolist (pair (alist-get 'files data))
          (puthash (car pair) (cdr pair) hash-cache-old))
        ;; Check shared deps hash
        (let ((old-deps-hash (alist-get 'shared-deps-hash data)))
          (unless (and old-deps-hash
                       (string= old-deps-hash (hash-shared-deps)))
            (message "Shared dependencies changed, forcing full rebuild")
            (setq force-full-rebuild t)))))))

(defun hash-cache-save ()
  "Save `hash-cache-new' to disk."
  (with-temp-file hash-cache-file
    (let ((pairs '()))
      (maphash (lambda (k v) (push (cons k v) pairs)) hash-cache-new)
      (prin1 `((shared-deps-hash . ,(hash-shared-deps))
               (files . ,pairs))
             (current-buffer))))
  (message "Hash cache saved: %d entries" (hash-table-count hash-cache-new)))

(defun hash-file-sha256 (filepath)
  "Compute SHA256 of FILEPATH contents."
  (with-temp-buffer
    (insert-file-contents-literally filepath)
    (secure-hash 'sha256 (current-buffer))))

(defun hash-string-sha256 (str)
  "Compute SHA256 of string STR."
  (secure-hash 'sha256 str))

(defun hash-org-file-with-includes (filepath)
  "Compute composite SHA256 of FILEPATH and any #+INCLUDE'd files."
  (let ((hashes (list (hash-file-sha256 filepath))))
    (with-temp-buffer
      (insert-file-contents filepath)
      (goto-char (point-min))
      (while (re-search-forward
              "^[ \t]*#\\+INCLUDE:\\s-+\"\\([^\"]+\\)\"" nil t)
        (let* ((inc-path (match-string 1))
               (inc-path (if (string-match "::.*\\'" inc-path)
                             (substring inc-path 0 (match-beginning 0))
                           inc-path))
               (inc-abs (expand-file-name inc-path
                                          (file-name-directory filepath))))
          (when (file-exists-p inc-abs)
            (push (hash-file-sha256 inc-abs) hashes)))))
    (hash-string-sha256 (mapconcat #'identity (nreverse hashes) ":"))))

(defun hash-shared-deps ()
  "Compute a combined hash of build config and shared assets.
Changes to these files affect all outputs."
  (let ((dep-files (list
                    (expand-file-name "build.el" default-directory)
                    (expand-file-name "build-adithya-cv.el" default-directory)
                    (expand-file-name "assets/syntax.css" default-directory)
                    (expand-file-name "assets/rich-inline.csl" default-directory))))
    (hash-string-sha256
     (mapconcat (lambda (f)
                  (if (file-exists-p f) (hash-file-sha256 f) "missing"))
                dep-files ":"))))

;; Load the cache (and check shared deps)
(hash-cache-load)
(when force-full-rebuild
  (message "Full rebuild: all files will be re-exported"))

;; --- Advice: content-hash check instead of mtime ---

(defun hash-based-publish-needed-p (orig-fn filename &rest args)
  "Use content hash for .org files, fall back to mtime for assets."
  (if (and (stringp filename) (string-suffix-p ".org" filename))
      (let* ((abs-path (expand-file-name filename))
             (current-hash (hash-org-file-with-includes abs-path))
             (cached-hash (gethash abs-path hash-cache-old))
             (changed (or force-full-rebuild
                          (null cached-hash)
                          (not (string= current-hash cached-hash)))))
        (puthash abs-path current-hash hash-cache-new)
        (when changed
          (message "Content changed: %s" (file-name-nondirectory filename)))
        changed)
    ;; Static assets: use original mtime check
    (apply orig-fn filename args)))

(advice-add 'org-publish-cache-file-needs-publishing
            :around #'hash-based-publish-needed-p)

;; Build CV PDF into assets/
(load-file "build-adithya-cv.el")
(let* ((cv-source (expand-file-name "CV.org" default-directory))
       (cv-hash (hash-file-sha256 cv-source))
       (cv-cached (gethash cv-source hash-cache-old))
       (cv-changed (or force-full-rebuild
                       (null cv-cached)
                       (not (string= cv-hash cv-cached)))))
  (puthash cv-source cv-hash hash-cache-new)
  (if cv-changed
      (progn (build-adithya-cv) (message "CV rebuilt"))
    (message "CV unchanged, skipping PDF generation")))

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
      org-html-htmlize-output-type 'css
      ;; Skip broken links (org-roam ID links won't resolve in batch mode)
      org-export-with-broken-links 'mark)

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
        <a href=\"%sCV.html\">CV</a>
        <a href=\"%snotes/index.html\">Notes</a>
        <a href=\"%sblogs/index.html\">Blog</a>
    </p>
  </nav>
</div>" site-root site-root site-root site-root site-root site-root))

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

;; --- Notes index generation ---
(defvar org-dir (getenv "ORG_DIR"))
(defvar notes-base-dir (when org-dir (file-name-concat org-dir "200-notes")))
(defvar notes-subdirs '(("literature-notes" . "literature notes")
                        ("permanent-notes" . "permanent notes")
                        ("protocols" . "protocols")))
(defvar notes-dir "notes")
(defvar notes-per-page 50)

(defun notes--extract-date-from-filename (filename)
  "Try to extract a YYYY-MM-DD date from FILENAME's timestamp prefix."
  (let ((name (file-name-nondirectory filename)))
    (cond
     ;; Denote format: 20241221T230010--title.org
     ((string-match "^\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T" name)
      (format "%s-%s-%s" (match-string 1 name) (match-string 2 name) (match-string 3 name)))
     ;; Zettelkasten format: 20241003013133-title.org
     ((string-match "^\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)[0-9]+-" name)
      (format "%s-%s-%s" (match-string 1 name) (match-string 2 name) (match-string 3 name)))
     (t nil))))

(defun notes--extract-metadata (file subdir-slug)
  "Extract title and date from an org FILE, tagging with SUBDIR-SLUG."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((title (when (re-search-forward "^#\\+[Tt][Ii][Tt][Ll][Ee]:\\s-*\\(.*\\)" nil t)
                   (string-trim (match-string 1))))
          (date (progn
                  (goto-char (point-min))
                  (cond
                   ;; Try #+date: <2024-01-08> or #+date: [2024-01-08 ...]
                   ((re-search-forward "^#\\+[Dd][Aa][Tt][Ee]:\\s-*[<\\[]\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t)
                    (match-string 1))
                   ;; Try #+date: 2024-01-08
                   ((progn (goto-char (point-min))
                           (re-search-forward "^#\\+[Dd][Aa][Tt][Ee]:\\s-*\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t))
                    (match-string 1))
                   ;; Fall back to filename
                   (t (notes--extract-date-from-filename file))))))
      (when title
        (list :title title
              :date (or date "0000-00-00")
              :file (file-name-nondirectory file)
              :subdir subdir-slug)))))

(defun notes--generate-page (entries page-num total-pages output-dir)
  "Generate a single notes index page with ENTRIES for PAGE-NUM of TOTAL-PAGES."
  (let* ((filename (if (= page-num 1) "index.org"
                     (format "page-%d.org" page-num)))
         (filepath (file-name-concat output-dir filename)))
    (with-temp-file filepath
      (insert "#+title: Notes\n\n")
      (dolist (entry entries)
        (let* ((title (plist-get entry :title))
               (date (plist-get entry :date))
               (file (plist-get entry :file))
               (subdir (plist-get entry :subdir))
               (html-file (concat (file-name-sans-extension file) ".html"))
               (label (replace-regexp-in-string "-" " " subdir)))
          (insert (format "@@html:<div class=\"note-entry\"><a href=\"%s/%s\">%s</a><br><span class=\"note-badge date-badge\">%s</span> <span class=\"note-badge source-badge\">%s</span></div>@@\n"
                          subdir html-file title date label))))
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
    (message "Generated notes index: %s" filepath)))

(defun generate-notes-index ()
  "Scan notes source directories, generate paginated index pages."
  (let ((notes-path (file-name-concat default-directory notes-dir))
        (all-entries '()))
    ;; Create local notes/ directory
    (unless (file-exists-p notes-path)
      (make-directory notes-path t))
    ;; Collect entries from all source directories
    (dolist (subdir-pair notes-subdirs)
      (let* ((slug (car subdir-pair))
             (dirname (cdr subdir-pair))
             (src-dir (file-name-concat notes-base-dir dirname)))
        (when (file-directory-p src-dir)
          (let ((org-files (directory-files src-dir t "\\.org$")))
            (dolist (f org-files)
              (let ((entry (notes--extract-metadata f slug)))
                (when entry
                  (push entry all-entries))))))))
    ;; Sort by date descending
    (setq all-entries (sort all-entries
                            (lambda (a b)
                              (string> (plist-get a :date) (plist-get b :date)))))
    (let* ((total (length all-entries))
           (total-pages (max 1 (ceiling (/ (float total) notes-per-page)))))
      ;; Clean old generated index files
      (dolist (f (directory-files notes-path t "^\\(index\\|page-[0-9]+\\)\\.org$"))
        (delete-file f))
      ;; Generate each page
      (dotimes (i total-pages)
        (let* ((start (* i notes-per-page))
               (end (min (* (1+ i) notes-per-page) total))
               (page-entries (seq-subseq all-entries start end)))
          (notes--generate-page page-entries (1+ i) total-pages notes-path)))
      (message "Notes index generated: %d notes across %d pages" total total-pages))))

;; Generate notes index before publishing
(when (and notes-base-dir (file-directory-p notes-base-dir))
  (generate-notes-index))

;; --- Org-ID resolution for org-roam links ---
(require 'org-id)

(defun build-org-id-db ()
  "Scan all notes files and register their :ID: properties for link resolution."
  (let ((count 0))
    (dolist (subdir-pair notes-subdirs)
      (let* ((dirname (cdr subdir-pair))
             (src-dir (file-name-concat notes-base-dir dirname)))
        (when (file-directory-p src-dir)
          (dolist (f (directory-files src-dir t "\\.org$"))
            (with-temp-buffer
              (insert-file-contents f)
              (goto-char (point-min))
              (while (re-search-forward ":ID:\\s-+\\([a-f0-9-]+\\)" nil t)
                (let ((id (match-string 1)))
                  (puthash id f org-id-locations)
                  (cl-incf count))))))))
    (message "Org-ID database built: %d IDs registered" count)))

(when (and notes-base-dir (file-directory-p notes-base-dir))
  (unless (hash-table-p org-id-locations)
    (setq org-id-locations (make-hash-table :test 'equal)))
  (build-org-id-db))

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
   "<link rel=\"stylesheet\" href=\"/assets/syntax.css\" type=\"text/css\" />\n"
   "<script id=\"MathJax-script\" async src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js\"></script>\n"))

;; Set up the org-publish project for the root index file.
(setq org-publish-project-alist
      ;; Publish the root index file
      `(("index-project"
         :base-directory ,default-directory
         :base-extension "org"
         :publishing-directory ,publish-dir
         :publishing-function org-html-publish-to-html
         :recursive nil
         :exclude "todo\\.org"
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

        ;; Publish the notes index (generated locally)
        ,@(when notes-base-dir
            `(("notes-index-project"
               :base-directory ,(file-name-concat default-directory "notes")
               :base-extension "org"
               :publishing-directory ,(file-name-concat publish-dir "notes")
               :publishing-function org-html-publish-to-html
               :recursive nil
               :html-head ,(html-head-fn)
               :section-numbers nil
               :html-preamble site-nav-html
               :html-postamble nil
               :with-toc nil)

              ;; Literature notes
              ("literature-notes-project"
               :base-directory ,(file-name-concat notes-base-dir "literature notes")
               :base-extension "org"
               :publishing-directory ,(file-name-concat publish-dir "notes" "literature-notes")
               :publishing-function org-html-publish-to-html
               :recursive nil
               :html-head ,(html-head-fn)
               :section-numbers nil
               :html-preamble site-nav-html
               :html-postamble nil
               :with-toc nil)
              ("literature-notes-images"
               :base-directory ,(file-name-concat notes-base-dir "literature notes" "images")
               :base-extension "png\\|jpg\\|gif\\|svg\\|pdf"
               :publishing-directory ,(file-name-concat publish-dir "notes" "literature-notes" "images")
               :recursive t
               :publishing-function org-publish-attachment)
              ("literature-notes-attach"
               :base-directory ,(file-name-concat notes-base-dir "literature notes" "attach")
               :base-extension "png\\|jpg\\|gif\\|svg\\|pdf"
               :publishing-directory ,(file-name-concat publish-dir "notes" "literature-notes" "attach")
               :recursive t
               :publishing-function org-publish-attachment)

              ;; Permanent notes
              ("permanent-notes-project"
               :base-directory ,(file-name-concat notes-base-dir "permanent notes")
               :base-extension "org"
               :publishing-directory ,(file-name-concat publish-dir "notes" "permanent-notes")
               :publishing-function org-html-publish-to-html
               :recursive nil
               :html-head ,(html-head-fn)
               :section-numbers nil
               :html-preamble site-nav-html
               :html-postamble nil
               :with-toc nil)
              ("permanent-notes-assets"
               :base-directory ,(file-name-concat notes-base-dir "permanent notes" "data")
               :base-extension "png\\|jpg\\|gif\\|svg\\|pdf\\|drawio"
               :publishing-directory ,(file-name-concat publish-dir "notes" "permanent-notes" "data")
               :recursive t
               :publishing-function org-publish-attachment)

              ;; Protocols
              ("protocols-project"
               :base-directory ,(file-name-concat notes-base-dir "protocols")
               :base-extension "org"
               :publishing-directory ,(file-name-concat publish-dir "notes" "protocols")
               :publishing-function org-html-publish-to-html
               :recursive nil
               :html-head ,(html-head-fn)
               :section-numbers nil
               :html-preamble site-nav-html
               :html-postamble nil
               :with-toc nil)))

        ;; Publish the assets directory
        ("assets-project"
         :base-directory ,assets-dir
         :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|ttf\\|woff\\|eot\\|svg"
         :publishing-directory ,(file-name-concat publish-dir assets-dir)
         :recursive t
         :publishing-function org-publish-attachment)))

;; Publish with cache-aware advice active
(let ((org-publish-use-timestamps-flag t))
  (org-publish-all nil))

;; Save the new hash cache for next build
(hash-cache-save)

(message "Build complete!")
;;; build.el ends here
