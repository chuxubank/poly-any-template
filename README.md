# poly-any-template

This repository contains three independently installable packages:
`poly-any-jinja2`, `poly-any-go-template`, and `poly-treesit-fold`. The two
template modes share the small helper in `poly-any-template.el`; the mode
before the template suffix is inferred from the filename:

| Filename | Host mode | Inner mode |
| --- | --- | --- |
| `config.json.j2` | JSON | Jinja2 |
| `values.yaml.jinja2` | YAML | Jinja2 |
| `deployment.yaml.gotmpl` | YAML | `go-template-ts-mode` |
| `page.html.gotmpl` | HTML | `go-template-ts-mode` |
| `deployment.yaml.tmpl` | YAML | `go-template-ts-mode` |
| `page.html.tmpl` | HTML | `go-template-ts-mode` |

Plain `.gotmpl` and `.tmpl` files continue to use `go-template-ts-mode`
directly.

## Installation

```elisp
(use-package go-template-ts-mode
  :vc (:url "https://github.com/chuxubank/go-template-ts-mode"))

(use-package poly-any-jinja2
  :vc (poly-any-jinja2
       :url "https://github.com/chuxubank/poly-any-template"
       :main-file "poly-any-jinja2.el")
  :demand t)

(use-package poly-any-go-template
  :vc (poly-any-go-template
       :url "https://github.com/chuxubank/poly-any-template"
       :main-file "poly-any-go-template.el")
  :demand t)

(use-package poly-treesit-fold
  :vc (poly-treesit-fold
       :url "https://github.com/chuxubank/poly-any-template"
       :main-file "poly-treesit-fold.el")
  :demand t
  :config
  (poly-treesit-fold-mode 1))
```

`poly-any-jinja2` requires Emacs 29.1+, `polymode`, and `jinja2-mode`.
`poly-any-go-template` requires Emacs 29.1+, `polymode`, and
`go-template-ts-mode`.

Customize `poly-any-jinja2-lighter` and `poly-any-go-template-lighter` to
change or hide their mode-line lighters. Both variables accept any mode-line
construct.

`poly-treesit-fold` requires Emacs 29.1+, `polymode`, and `treesit-fold`. It
selects the parser belonging to the current polymode span and registers Go
Template folds for `if`, `range`, `with`, `define`, and `block` actions.

## License

GPL-3.0-or-later.
