;; ;; (when (buffer-newly-created? (current-buffer))
;; ;;   (set-style-list (append (get-style-list) '("CustomStyle")))
;; ;;   ;; prevent TeXmacs from thinking the buffer has been modified by the change of
;; ;;   ;; style, or it would always prompt asking for confirmation before closing an
;; ;;   ;; empty buffer.
;; ;;   (buffer-pretend-saved (current-buffer)))
;; (menu-bind file-menu
;;            (former)
;;            ---
;;            ("Get Export Buffer" (switch-to-export-buffer)))

;; ;; This function is created to resolve citation issue with beamer export
;; (tm-define (switch-to-export-buffer)
;;            (if (screens-buffer?)
;;                (let* ((cur (current-buffer))
;;                       (buf (buffer-new))
;;                       (buf1 (buffer-new)))
;;                  (buffer-copy cur buf)
;;                  (buffer-set-master buf cur)
;;                  (switch-to-buffer buf)
;;                  (dynamic-make-slides)
;;                  )
;;                (let* ((cur (current-buffer))
;;                       (buf (buffer-new)))
;;                  (buffer-copy cur buf)
;;                  (buffer-set-master buf cur)
;;                  (switch-to-buffer buf))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;; Transform presentation into slides
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (define (dynamic-first-alternative-list l)
;;   (if (null? l) #f
;;       (with r (dynamic-first-alternative (car l))
;;         (or r (dynamic-first-alternative-list (cdr l))))))

;; (define (dynamic-first-alternative t)
;;   (cond ((and (alternative-context? t) (> (tm-arity t) 1)) t)
;;         ((overlays-context? t)
;;          (tree-set! t 0 "1")
;;          (tree-assign-node! t 'overlays-range)
;;          t)
;;         ((and (tree-is? t 'overlays-range)
;;               (< (tree->number (tree-ref t 0))
;;                  (tree->number (tree-ref t 1)))) t)
;;         ((not (tm-compound? t)) #f)
;;         (else (dynamic-first-alternative-list (tm-children t)))))

;; (define (dynamic-alternative-keep-first slide)
;;   (and-with t (dynamic-first-alternative slide)
;;     (cond ((alternative-context? t)
;;            (tree-remove t 1 (- (tree-arity t) 1)))
;;           ((tree-is? t 'overlays-range)
;;            (tree-set t 1 (tree-copy (tree-ref t 0)))))
;;     (dynamic-alternative-keep-first slide)))

;; (define (dynamic-alternative-keep-other slide)
;;   (and-with t (dynamic-first-alternative slide)
;;     (cond ((alternative-context? t)
;;            (tree-remove t 0 1))
;;           ((tree-is? t 'overlays-range)
;;            (with nr (tree->number (tree-ref t 0))
;;              (tree-set t 0 (number->string (+ nr 1))))))))

;; (define (dynamic-make-slide t)
;;   (when (or (tm-func? t 'shown 1) (hidden-context? t))
;;     (tree-assign-node! t 'slide))
;;   (if (and (tm-func? t 'slide 1) (dynamic-first-alternative t))
;;       (let* ((p (tree-up t))
;;              (i (tree-index t)))
;;         (tree-insert p (+ i 1) (list (tree-copy t)))
;;         (let* ((v  (tree-ref p i))
;;                (w  (tree-ref p (+ i 1))))
;;           (dynamic-alternative-keep-first v)
;;           (dynamic-alternative-keep-other w)
;;           (dynamic-make-slide v)
;;           (dynamic-make-slide w)))
;;       (dynamic-operate (tree-ref t 0) :var-expand)))

;; (define (keep-shown! t)
;;   (if (alternative-context? t)
;;       (map ;; Prune hidden children
;;        (lambda (i) (if (tm-func? (tree-ref t i) 'hidden)
;;                        (tree-remove! t i 1)))
;;        (reverse (.. 0 (tm-arity t)))))
;;   (if (and (tm-compound? t) (> (tm-arity t) 0))
;;       (for-each keep-shown! (tree-children t))))

;; (define (create-slide scr)
;;   (if (not (tree? scr)) (tree 'slide '(document "")) ;; just in case
;;       (with t (tree-copy scr)
;;         (keep-shown! t)
;;         (tree-assign-node! t 'slide)
;;         t)))

;; (define (process-screen scr)
;;   (cons (create-slide scr)
;;         (begin
;;           (dynamic-traverse-buffer :next)
;;           (if (tm-func? scr 'hidden) '()
;;               (process-screen scr)))))

;; (define (list->tree label l)
;;   (tree-insert (tree label) 0 l))

;; (define (screens->slides t)
;;   (if (not (tm-func? t 'screens)) (tree 'document "")
;;       (with f (lambda (scr) (list->tree 'document (process-screen scr)))
;;         ;; (system-wait "Generating slides" "please wait") ;crashes if printing
;;         ;; Insert fake screen at the end
;;         (tree-insert! t (tree-arity t)
;;                       (list (tree 'hidden '(document ""))))
;;         (dynamic-operate-on-buffer :first)
;;         ;; Notice that we don't process the last (fake) screen
;;         (list->tree 'screens (map f (cDr (tree-children t)))))))

;; (define (transform-last-slide doc)
;;   (cond ((tree-is? doc 'screens) (transform-last-slide (tm-ref doc :last)))
;; 	((tree-is? doc 'document) (transform-last-slide (tm-ref doc :last)))
;; 	((tree-func? doc 'slide 1) (tree-set! doc (tm-ref doc 0)))))
