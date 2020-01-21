(texmacsa-module (bibtex example)
                 (:use (bibtex bib-utils)))

(bib-define-style "example" "plain")

(tm-define (bib-format-date e)
           (:mode bib-example?)
           (bib-format-field e "year"))b




