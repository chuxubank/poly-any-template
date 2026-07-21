# poly-any-template

This repository contains several independently installable packages in one
VC repository. Each package has its own `lisp-dir`, so `package-vc` exposes
only the requested package on `load-path`:

| Package | `lisp-dir` | Purpose |
| --- | --- | --- |
| `poly-any-template` | `lisp/shared` | Shared host-mode inference and Polymode activation |
| `poly-any-jinja2` | `lisp/jinja2` | Jinja2 templates in an inferred host mode |
| `poly-any-go-template` | `lisp/go-template` | Go templates in an inferred host mode |
| `poly-ansible-jinja2` | `lisp/ansible` | Ansible project and template conventions |
| `poly-any-template-indent-bars` | `lisp/indent-bars` | Optional `indent-bars` integration |
| `poly-treesit-fold` | `lisp/treesit-fold` | Optional `treesit-fold` integration |

The template modes depend on the shared package. The integration packages
are optional and are not referenced by the shared package or template modes.

The mode before the template suffix is inferred from the filename:

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

Install `poly-ansible-jinja2` to recognize the layouts from Ansible's
[sample setup](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html)
without maintaining custom rules. It covers top-level and `playbooks/`
playbooks, role tasks and metadata, inventory variables, Molecule scenarios,
projects identified by their standard directories or configuration files,
Jinja-suffixed files below `templates` directories, and suffixless templates
inside roles or marked Ansible projects. Host modes are inferred after the
Jinja2 suffix is removed, so `templates/nginx.conf.j2` uses `conf-mode` and
`templates/Brewfile.j2` uses `ruby-mode`. A hostless template such as
`templates/env.j2` uses `text-mode` as its host instead of falling back to the
pure Jinja2 mode. Ansible YAML source files also enable `ansible-mode` and
`ansible-doc-mode`; rendered files in `templates` do not. Customize
`poly-ansible-jinja2-project-markers` when a project uses a different root
marker or a global marker should be ignored.

## Installation

Install the shared package and whichever template modes you use. Explicit
package names and `:lisp-dir` values are required because the repository
contains multiple packages.

```elisp
(use-package jinja2-ts-mode
  :vc (:url "https://github.com/chuxubank/jinja2-ts-mode"))

(use-package go-template-ts-mode
  :vc (:url "https://github.com/chuxubank/go-template-ts-mode"))

(use-package poly-any-template
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/shared"))

(use-package poly-any-jinja2
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/jinja2")
  :demand t)

(use-package poly-any-go-template
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/go-template")
  :demand t)
```

The Ansible, indentation, and folding integrations are independent and may
be installed separately:

```elisp
(use-package poly-ansible-jinja2
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/ansible"))

(use-package poly-any-template-indent-bars
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/indent-bars")
  :hook
  (poly-any-template-after-activate . poly-any-template-indent-bars-mode))

(use-package poly-treesit-fold
  :vc (:url "https://github.com/chuxubank/poly-any-template"
       :lisp-dir "lisp/treesit-fold")
  :demand t
  :config
  (poly-treesit-fold-mode 1))
```

The `indent-bars` adapter is loaded lazily by
`poly-any-template-after-activate-hook`; it does not need `:demand t`.
`poly-treesit-fold-mode` is global, so the example deliberately uses
`:demand t` to install its parser-selection advice during startup.

`poly-any-jinja2` requires Emacs 29.1+, `polymode`, and
`jinja2-ts-mode` 0.1.1+.
`poly-ansible-jinja2` additionally requires `ansible`, `ansible-doc`, and
`yaml-mode`; it does not depend on the older `poly-ansible` package. A
configured `yaml-ts-mode` file association can still take precedence over
`yaml-mode` for the host buffer.
`poly-any-go-template` requires Emacs 29.1+, `polymode`, and
`go-template-ts-mode` 0.1.7+.
`poly-any-template-indent-bars` additionally requires `indent-bars`.

Customize `poly-any-jinja2-lighter` and `poly-any-go-template-lighter` to
change or hide their mode-line lighters. Both variables accept any mode-line
construct.

`poly-any-template-indent-bars` keeps `indent-bars-mode` enabled in template
polymodes while selecting its regular font-lock backend locally. This avoids
the Tree-sitter backend suppressing Poly-lock's language fontifier in indirect
buffers. Inner spans are filtered from the host's blank-line pass so
template-action lines do not gain trailing guides, while real blank lines
continue to display normally.

`poly-treesit-fold` requires Emacs 29.1+, `polymode`, and `treesit-fold`. It
selects the parser belonging to the current polymode span. Fold ranges remain
owned by their language modes; `go-template-ts-mode` and `jinja2-ts-mode`
provide their integrations automatically when `treesit-fold` is loaded.

## Development

Install the development dependencies once, then build and run all package
tests through the Makefile:

```sh
make install-deps
make
```

Individual suites are available as `make test-jinja2`, `make test-ansible`,
`make test-go-template`, `make test-indent-bars`, and
`make test-treesit-fold`.

## License

GPL-3.0-or-later.
