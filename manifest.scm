(define pkg (load "./guix.scm"))

(concatenate-manifests
 (list
  (specifications->manifest
   '("python-black"
     "python-flake8"))
  (package->development-manifest pkg)))
