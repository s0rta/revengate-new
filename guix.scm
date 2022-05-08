;;; Revengate package for GNU Guix
;;; Copyright © 2022 Ryan Prior <rprior@protonmail.com>

(define-module (revengate guix)
  #:use-module (gnu packages check)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages libbsd)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system python)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(let ((project-dir (dirname (current-filename))))
  (define-public revengate
    (package
      (name "revengate")
      (version "0.0.1")
      (source (local-file project-dir #:recursive? #t))
      (build-system python-build-system)
      (arguments
       '(#:phases
         (modify-phases %standard-phases
           (replace 'check
             (lambda _
               (invoke/quiet "pytest"))))))
      (native-inputs (list git python-setuptools-scm python-pytest))
      (inputs
       (list python python-tomlkit python-click python-kivy python-kivymd
             python-pillow libbsd mesa libx11))
      (synopsis "Victorian steampunk adventure game with political intrigue and sword fights.")
      (description "Revengate takes place in a steampunk parallel universe closely
based on Earth in the Victorian era. Magic exists, human races are more spread
out than they are on our Earth, guns are still impractical, Europe is widely
developed, but so are many other cities around the world.


The game starts in 955 AD, which roughly corresponds to 1855 of our world. The
setting is Victorian era Franconia, located roughly where modern France is.

Technology, science, and medicine is comparable to that of 1855 of our world,
except for a few specific discoveries that came a couple decades early or a
couple decades late. The industrial revolution is getting started. Guns are all
impractical muzzle loaders. Magic is fairly common and its proponents are at odd
with the industrial elite. Electricity is rare, steam and clockwork mechanisms
are the main sources of mechanized work. Hot air balloons can be seen once in a
while, steerable airships are about to be invented.

There are many ideological conflicts in the world: science vs magic, democracy
vs autocratic rule, hedonism vs industrial efficiency, colonialism vs local
autonomy. In time, the hero will get to pick a side for many of these conflicts,
with pro and cons on both sides of the conflicts.")
      (home-page "http://revengate.org/")
      (license license:gpl3+)))

  revengate)
