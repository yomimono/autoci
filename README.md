## What is this?

A few tools for automatically handling cloud CI tests for projects that use `opam`.

## Why would I want this?

* For a given repository, you want to generate cloud CI configurations that:
  * test that your software can be correctly installed/removed completely by opam
  * see whether any tests you run on your software passed or failed
* For a given repository, you want to ensure that:
  * each package with an opam file in the repository will have its installation tested by cloud CI
  * each package with defined tests will have those tests run by cloud CI
  * each package with optional dependencies will test its installation in the presence of all optional dependencies

## How do I use it?

Command-line tools expose a `--help` option which is most likely to be up-to-date.  The binaries which currently exist are:
  * `autotravis` for automatically generating Travis CI configurations from opam files
  * `autoappveyor` for automatically generating Appveyor configurations from opam files
  * `travis-to-appveyor` for generating Appveyor configurations from Travis configurations
  * `lint` for checking whether Travis CI configurations are sensible

Both tools can take arguments for `opam` files and cloud CI configurations to consider; if those arguments are omitted, they will attempt to discover them in the current directory.  For example, one might use `autotravis` to generate a Travis CI configuration for `autoci` itself:

```
4.05.0+afl🐫  (primary) 13.29 mirageos:~/autoci$ _build/default/src/autotravis.exe 
language: c
install: wget https://raw.githubusercontent.com/ocaml/ocaml-ci-scripts/master/.travis-docker.sh
script: bash -ex .travis-docker.sh
services:
- docker
env:
  global:
  - PINS="autoci:."
  - DISTRO="ubuntu-16.04"
  matrix:
  - PACKAGE="autoci" OCAML_VERSION="4.03.0"
  - PACKAGE="autoci" OCAML_VERSION="4.04.2"
  - PACKAGE="autoci" OCAML_VERSION="4.05.0"
  - PACKAGE="autoci" OCAML_VERSION="4.06.0"
```

or use `lint` to check whether a complex project is testing everything it should be:

```
4.05.0+afl🐫  ((detached from origin/master)) 13.30 mirageos:~/mirage-net-xen$ ~/autoci/_build/default/src/lint.exe 
Packages whose installation is not tested (add them to the matrix): netchannel
```
