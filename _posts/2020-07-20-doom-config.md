---
layout: post
title: My Academic Doom Emacs Config
---

Hi.

Here, I have documented my Doom emacs way for better note-taking and reference management.

---

## Org-roam

`Org-roam` allows you to think from the perspective of the content and forces you to connected related content together. I find this helpful and mainly use it to do the following when reading papers:
- Whenever I find a new environment such as, say, the *Random Oracle* assumption, I
  link it to an empty note `RandomOracleAssumption.org`. Org-roam automatically
  generates back-links to this note. This lets me see all papers that use that
  assumption.
- Additionally, in `RandomOracleAssumption.org` file I add a link to the first
  paper that defines this assumption. This allows me to quickly cite the first
  paper that introduced that environment.
  
---
  
## Bibtex-completion and Ivy-bibtex

Whenever I need to read a paper, I use google scholar to find the bibtex entry for that paper. Then I use ivy-bibtex to add a bibtex entry for the paper. Quickly typing `SPC-n-b` allows me to view all the papers I have read. If I find a PDF, 
1. I download it to a specific directory `Papers-PDF` in my `org-roam-directory`. 
2. I then add `file={path/to/pdf}` in the bibtex entry.

---

## Org-noter

The `Org-noter` package allows me to take org notes on a PDF in locations that are synced with the page. Since I have already configured `ivy-bibtex`, on selecting a bibtex it automatically opens the PDF of the paper on disk. Now I can quikcly type `SPC-n-e` to start an org-noter-session for that paper. This creates an org-note for that paper. 
There is a handy function `org-noter-create-skeleton` that builds an outline of the pdf in the note. Typing `C-M-.` quickly syncs the pdf to the heading of the outline. Not all pdfs work though.

The default headers are insufficient and I typically tend to add the following additional settings to all the note files.

```
#+ROAM_KEY: cite:bibtex-key-of-reference
#+ROAM_TAGS:
#+STARTUP: latexpreview
#+AUTHOR: Adithya Bhat
...
```

Org-noter also has this killer feature `org-noter-insert-precise-note` where I can click on a precise location and add a note in my org file. Then on clicking the note, it shows a red arrow in the PDF. This is useful when I want to cite the paper on comments that the paper makes.

---

## Maintaining a Reading List

I often find a bunch of papers that I have to read but eventually forget them.
Org mode has a system to quickly capture such fleeting ideas and concepts.
Therefore, I added a quick-capture entry (triggered by running `SPC-X-r`) for
quickly adding papers that I need to read. I can refer my reading list file `ReadingList.org` anytime afterwards to add it to my `.bib` file and make notes. 

```elisp
;; Add reading list to org-capture
(after! org
  (add-to-list 'org-capture-templates
             '("r" "Reading List" entry
               (file+headline "ReadingList.org" "To Read")
               "* TODO %T [ ] %?"
               :kill-buffer t
               :empty-lines-after 1
               :empty-lines-before 1)))

```

---

## Org-roam-server

Org-roam-server helps visualize the connections between the notes that I have taken.
This also helps me make additional connections between notes when relevant.

![Org-roam-server in action](/assets/img/org-roam-server.png)

---

## Conclusion

This is my current setup for academic note taking using Doom Emacs. For comments
and suggestions please feel free to drop an [email](mailto:dth.bht@gmail.com) to
me. I am sure the process can be sped up significantly and I will keep this post
updated as I discover more features.

---

### Config Files

My config files can be found [here]().

---

