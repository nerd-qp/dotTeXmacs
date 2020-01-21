# dotTeXmacs
TeXmacs scheme extension scripts.

# Functionality implemented
This repository contains my daily .TeXmacs configuration. I implement two functionalities as of now, all based on original code, and additional hacking on my own. In addition, it also includes copy-paste code from [slowphil](https://github.com/slowphil/zotexmacs) for better Zotero-TeXmacs integration.

Funtionalies:

1. Generation of html file with additional yaml style to for better Hugo statis generation.
2. Fix slides generation, which has question mark if used with bib citation. The implementation first combines all slides together and obtains the buffer, then export as pdf manually. For unknown reason, it fixes the annoying question mark generated with original implementation.