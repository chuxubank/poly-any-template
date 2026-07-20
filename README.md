# poly-any-template

This repository contains three independently installable user-facing
packages: `poly-any-jinja2`, `poly-any-go-template`, and
`poly-treesit-fold`. It also contains the internal `poly-any-template` shared
package required by the two template modes. Each package has its own
`lisp-dir`, so installing multiple packages from this repository cannot
expose duplicate copies of the shared implementation on `load-path`. The
mode before the template suffix is inferred from the filename:

| Filename | Host mode | Inner mode |
| --- | --- | --- |
| `config.json.j2` | JSON | `jinja2-ts-mode` |
| `values.yaml.jinja` | YAML | `jinja2-ts-mode` |
| `values.yaml.jinja2` | YAML | `jinja2-ts-mode` |
| `deployment.yaml.gotmpl` | YAML | `go-template-ts-mode` |
| `page.html.gotmpl` | HTML | `go-template-ts-mode` |
| `deployment.yaml.tmpl` | YAML | `go-template-ts-mode` |
| `page.html.tmpl` | HTML | `go-template-ts-mode` |

Plain `.j2`, `.jinja`, and `.jinja2` files use `jinja2-ts-mode` directly.
Plain `.gotmpl` and `.tmpl` files use `go-template-ts-mode` directly. A
compound filename or a matching extra rule still activates Polymode with the
inferred host mode.

Customize `poly-any-jinja2-extra-file-name-rules` or
`poly-any-go-template-extra-file-name-rules` for templates selected by path or
naming convention instead of a template suffix. Each rule may be a regexp or
a function accepting the file name. The host filename keeps its final
extension for these rules unless the file still has a standard template
suffix.

```elisp
(setq poly-any-jinja2-extra-file-name-rules
      '("/ansible/.*\\.ya?ml\\'"
        "/\\(?:group\\|host\\)_vars/"))
```

## Installation

```elisp
(use-package jinja2-ts-mode
  :vc (:url "https://github.com/chuxubank/jinja2-ts-mode"))

(use-package go-template-ts-mode
  :vc (:url "https://github.com/chuxubank/go-template-ts-mode"))

(use-package poly-any-template
  :vc (poly-any-template
       :url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/shared"))

(use-package poly-any-jinja2
  :vc (poly-any-jinja2
       :url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/jinja2")
  :demand t)

(use-package poly-any-go-template
  :vc (poly-any-go-template
       :url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/go-template")
  :demand t)

(use-package poly-treesit-fold
  :vc (poly-treesit-fold
       :url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/treesit-fold")
  :demand t
  :config
  (poly-treesit-fold-mode 1))
```

`poly-any-jinja2` requires Emacs 29.1+, `polymode`, and
`jinja2-ts-mode` 0.1.1+.
`poly-any-go-template` requires Emacs 29.1+, `polymode`, and
`go-template-ts-mode` 0.1.4+.

Customize `poly-any-jinja2-lighter` and `poly-any-go-template-lighter` to
change or hide their mode-line lighters. Both variables accept any mode-line
construct.

Template polymodes preserve blank-line guides from `indent-bars`. Inner spans
are filtered from the host's blank-line pass so template-action lines do not
gain trailing guides, while real blank lines continue to display normally.

`poly-treesit-fold` requires Emacs 29.1+, `polymode`, and `treesit-fold`. It
selects the parser belonging to the current polymode span. Fold ranges remain
owned by their language modes; `go-template-ts-mode` and `jinja2-ts-mode`
provide their integrations automatically when `treesit-fold` is loaded.

## License

GPL-3.0-or-later.
