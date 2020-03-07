;; Stupid lazy loading. Need to explicitly call this out.
(use-modules (texmacs menus file-menu))
(use-modules (texmacs menus tools-menu))
(use-modules (convert markdown init-markdown))
;(use-modules (convert hugo-html init-hugo-html))

(menu-bind file-menu
           (former)
           ---
           ("Get Export Buffer" (switch-to-export-buffer)))

(menu-bind tools-menu
           (former)
           (-> "Blog"
               ("Create Hugo Blog" (tmblog-interactive-build))
               ("Update Hugo Blog" (tmblog-interactive-update))))

(tm-define (tmblog-interactive-build)
  (:interactive #t)
  (user-url "Source directory" "directory"
            (lambda (src)
              (user-url "Destination directory" "directory"
                        (lambda (dest)
                          (tmweb-convert-directory src dest #f #f))))))

(tm-define (tmblog-interactive-update)
  (:interactive #t)
  (user-url "Source directory" "directory"
            (lambda (src)
              (user-url "Destination directory" "directory"
                        (lambda (dest)
                          (tmweb-convert-directory src dest #t #f))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Building a web site
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Assume only one title
(define (blog-add-front-matter tm-file html-file)
  (let* ((html-str (string-load html-file))
         (doc-data (tree-ref (buffer-tree) 'doc-data))
         (title (tree-ref doc-data 'doc-title 0))
         (author-name (tree-ref doc-data
                                'doc-author
                                'author-data
                                'author-name 0))
         (doc-date (tree-ref doc-data 'doc-date 0))
         (front-matter "---\n"))
    (when title
      (set! front-matter (string-append front-matter
                                        "title: \"" (tree->string title)
                                        "\"\n")))
    (when author-name
      (set! front-matter (string-append front-matter
                                        "author: \"" (tree->string author-name)
                                        "\"\n")))
    ;;(display (tree->string (tree-ref 'doc-data 'date)))
    (if doc-date
      (set! front-matter (string-append front-matter
                                        "date: " (tree->string doc-date)
                                        "\n"))
      (set! front-matter (string-append front-matter
                                        "date: " (number->string
                                                  (url-last-modified tm-file))
                                        "\n")))
    (set! front-matter (string-append front-matter "---\n"))
    ;; (display* front-matter)
    (string-save (string-append front-matter html-str) html-file)))

(define (tmweb-make-dir dir html-dir)
  (when (and (!= dir html-dir) (!= dir (system->url ".")))
    (tmweb-make-dir (url-expand (url-append dir (url-parent))) html-dir))
  (when (not (url-exists? dir))
    (display* "TeXmacs] Creating directory " (url->system dir) "\n")
    (system-mkdir dir)
    (system-1 "chmod a+x" dir)))

(define (tmweb-convert-file tm-file html-file)
  ;; I assume that with-aux switch to this tm-file as buffer
  (with-aux tm-file
    (if (url? html-file) (set! current-save-target html-file))
    (begin
      (export-buffer-main (current-buffer) html-file "html" (list :overwrite))
      (blog-add-front-matter tm-file html-file))))

(define (needs-update? src dest update?)
  (or (not update?)
      (not (url-exists? dest))
      (url-newer? src dest)))

(define (tmweb-convert-file-dir file tm-dir html-dir update?)
  (let* ((m? (== (get-preference "texmacs->html:mathml") "on"))
	 (u1 (url-delta (url-append tm-dir "dummy") file))
	 ;; (u2 (url-glue (url-unglue u1 2) (if m? "xhtml" "html")))
   (u2 (url-glue (url-unglue u1 2) "html"))
	 (u3 (url-append html-dir u2))
	 (dir (url-expand (url-append u3 (url-parent))))
	 (dir-name (url->system (url-tail dir))))
    (when (and (!= dir-name "CVS") (!= dir-name ".svn")
	       (!= dir-name "prop-base") (!= dir-name "text-base"))
      (tmweb-make-dir dir (url-expand html-dir))
      (when (needs-update? file u3 update?)
        (system-wait "Converting" (url->system u1))
        (display* "TeXmacs] Converting " (url->system u1) "\n")
        (tmweb-convert-file file u3)))))

(define (tmweb-copy-file-dir file tm-dir html-dir update?)
  (let* ((u1 (url-delta (url-append tm-dir "dummy") file))
	 (u2 (url-append html-dir u1))
	 (name (url->system (url-tail u2)))
	 (dir (url-expand (url-append u2 (url-parent))))
	 (dir-name (url->system (url-tail dir))))
    (when (and (!= dir-name "CVS")
	       (!= dir-name "prop-base")
               (!= dir-name "text-base")
               (not (string-occurs? "/." (url->system u2)))
	       (not (string-ends? name "~"))
               (not (string-ends? name "#")))
      (tmweb-make-dir dir (url-expand html-dir))
      (when (needs-update? file u2 update?)
        (system-wait "Copying" (url->system u1))
        (display* "TeXmacs] Copying " (url->system u1) "\n")
        (system-copy file u2)))))

(define (tmweb-convert-directory tm-dir html-dir update? keep?)
  (let* ((u1 (url-append tm-dir (url-any)))
	 (u2 (url-expand (url-complete u1 "dr")))
	 (u3 (url-append u2 (url-wildcard "*.tm")))
	 (u4 (url-expand (url-complete u3 "fr")))
	 (u5 (url-expand (url-complete u1 "fr"))))
    (when (!= html-dir tm-dir)
      (for-each (lambda (x) (tmweb-copy-file-dir x tm-dir html-dir update?))
                (if keep? (url->list u5)
                    (list-difference (url->list u5) (url->list u4)))))
    (for-each (lambda (x) (tmweb-convert-file-dir x tm-dir html-dir update?))
	      (url->list u4))))

(define-preferences   ("zotero-server" #t noop))

(if (get-preference "zotero-server")
    (begin
      ;; Do (server-start) automatically at boot-up if preferences are set so
      ;; to enable incoming connections
      (import-from (server server-base)) ;; define tm-service for use below
      (with srv (client-start "localhost")
            (if (== srv -1)
                (begin (display "starting server\n")  ; no texmacs server was found : start it
                       (server-start))
                (begin (display "found local server\n")(client-stop srv)  ; a texmacs server is already started (in another instance, for example)
                       )))
      ;; define a login for connecting to texmac's server
      (server-set-user-information "zotero" "zotero-remote-cite" "zotero" "" "no")

      ;; define service that zotexmacs uses

      (tm-service (remote-cite key)
                  (if (list? key)
                      (insert (append '(cite) key))
                      (insert `(cite ,key)))
                  (merge-cite-tags)
                  (server-return envelope #t))

      ;; if there are adjascent cite tags, merge them all
      (define (merge-cite-tags)
        (let ((ps (path-paragraph-start)))
          (while (tm-is? (before-cursor) 'cite)
                 (traverse-left)
                 (if  (path-less? ps (path-previous (root-tree) (cursor-path)))
                      (go-to-previous))
                 ))
        (let* ((pstart (cursor-path))
               (cite+keys (list 'cite)))
          (while (tm-is? (after-cursor) 'cite)
                 (begin (append! cite+keys (cdr (tree->stree (after-cursor))))
                        (traverse-right)))
          (selection-set pstart (cursor-path))
          (clipboard-cut "nowhere")
          (insert cite+keys)
          (add-undo-mark)) ;; Doesn't work??
        )

      (define (path-paragraph-start)
        (let* ((cp (cursor-path))
               (ps (begin (go-start-paragraph) (cursor-path))))
          (go-to-path cp)
          ps))
      ))

;; This function is created to resolve citation issue with beamer export
(define (switch-to-export-buffer)
  (if (screens-buffer?)
      (let* ((cur (current-buffer))
             (buf (buffer-new))
             (buf1 (buffer-new)))
        (buffer-copy cur buf)
        (buffer-set-master buf cur)
        (switch-to-buffer buf)
        (dynamic-make-slides)
        )
      (let* ((cur (current-buffer))
             (buf (buffer-new)))
        (buffer-copy cur buf)
        (buffer-set-master buf cur)
        (switch-to-buffer buf))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Transform presentation into slides
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (dynamic-first-alternative-list l)
  (if (null? l) #f
      (with r (dynamic-first-alternative (car l))
            (or r (dynamic-first-alternative-list (cdr l))))))

(define (dynamic-first-alternative t)
  (cond ((and (alternative-context? t) (> (tm-arity t) 1)) t)
        ((overlays-context? t)
         (tree-set! t 0 "1")
         (tree-assign-node! t 'overlays-range)
         t)
        ((and (tree-is? t 'overlays-range)
              (< (tree->number (tree-ref t 0))
                 (tree->number (tree-ref t 1)))) t)
        ((not (tm-compound? t)) #f)
        (else (dynamic-first-alternative-list (tm-children t)))))

(define (dynamic-alternative-keep-first slide)
  (and-with t (dynamic-first-alternative slide)
            (cond ((alternative-context? t)
                   (tree-remove t 1 (- (tree-arity t) 1)))
                  ((tree-is? t 'overlays-range)
                   (tree-set t 1 (tree-copy (tree-ref t 0)))))
            (dynamic-alternative-keep-first slide)))

(define (dynamic-alternative-keep-other slide)
  (and-with t (dynamic-first-alternative slide)
            (cond ((alternative-context? t)
                   (tree-remove t 0 1))
                  ((tree-is? t 'overlays-range)
                   (with nr (tree->number (tree-ref t 0))
                         (tree-set t 0 (number->string (+ nr 1))))))))

(define (dynamic-make-slide t)
  (when (or (tm-func? t 'shown 1) (hidden-context? t))
    (tree-assign-node! t 'slide))
  (if (and (tm-func? t 'slide 1) (dynamic-first-alternative t))
      (let* ((p (tree-up t))
             (i (tree-index t)))
        (tree-insert p (+ i 1) (list (tree-copy t)))
        (let* ((v  (tree-ref p i))
               (w  (tree-ref p (+ i 1))))
          (dynamic-alternative-keep-first v)
          (dynamic-alternative-keep-other w)
          (dynamic-make-slide v)
          (dynamic-make-slide w)))
      (dynamic-operate (tree-ref t 0) :var-expand)))

(define (keep-shown! t)
  (if (alternative-context? t)
      (map ;; Prune hidden children
       (lambda (i) (if (tm-func? (tree-ref t i) 'hidden)
                       (tree-remove! t i 1)))
       (reverse (.. 0 (tm-arity t)))))
  (if (and (tm-compound? t) (> (tm-arity t) 0))
      (for-each keep-shown! (tree-children t))))

(define (create-slide scr)
  (if (not (tree? scr)) (tree 'slide '(document "")) ;; just in case
      (with t (tree-copy scr)
            (keep-shown! t)
            (tree-assign-node! t 'slide)
            t)))

(define (process-screen scr)
  (cons (create-slide scr)
        (begin
          (dynamic-traverse-buffer :next)
          (if (tm-func? scr 'hidden) '()
              (process-screen scr)))))

(define (list->tree label l)
  (tree-insert (tree label) 0 l))

(define (screens->slides t)
  (if (not (tm-func? t 'screens)) (tree 'document "")
      (with f (lambda (scr) (list->tree 'document (process-screen scr)))
            ;; (system-wait "Generating slides" "please wait") ;crashes if printing
            ;; Insert fake screen at the end
            (tree-insert! t (tree-arity t)
                          (list (tree 'hidden '(document ""))))
            (dynamic-operate-on-buffer :first)
            ;; Notice that we don't process the last (fake) screen
            (list->tree 'screens (map f (cDr (tree-children t)))))))

(define (transform-last-slide doc)
  (cond ((tree-is? doc 'screens) (transform-last-slide (tm-ref doc :last)))
        ((tree-is? doc 'document) (transform-last-slide (tm-ref doc :last)))
        ((tree-func? doc 'slide 1) (tree-set! doc (tm-ref doc 0)))))

;; Local Variables:
;; mode: scheme
;; eval: (put 'tm-define 'scheme-indent-function 1)
;; eval: (put 'with 'scheme-indent-function 1)
;; eval: (put 'with-aux 'scheme-indent-function 1)
;; End:


