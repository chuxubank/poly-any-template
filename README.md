# poly-any-template

`poly-any-template` provides host-aware polymodes for Jinja2 and Go template
files. The implementation is split into `poly-any-jinja2.el` and
`poly-any-go-template.el`; the mode before the template suffix is inferred
from the filename:

| Filename | Host mode | Inner mode |
| --- | --- | --- |
| `config.json.j2` | JSON | Jinja2 |
| `values.yaml.jinja2` | YAML | Jinja2 |
| `deployment.yaml.gotmpl` | YAML | `go-template-ts-mode` |
| `page.html.gotmpl` | HTML | `go-template-ts-mode` |

Plain `.gotmpl` files continue to use `go-template-ts-mode` directly.

## Installation

```elisp
(use-package go-template-ts-mode
  :vc (:url "https://github.com/chuxubank/go-template-ts-mode"))

(use-package poly-any-template
  :vc (:url "https://github.com/chuxubank/poly-any-template")
  :demand t)
```

The package requires Emacs 29.1+, `polymode`, `jinja2-mode`, and
`go-template-ts-mode`.

## License

GPL-3.0-or-later.
