import os
from invoke import task


def is_newer(fname, ref):
    """ Return whether fname is newer than file at ref. """
    if not os.path.isfile(fname):
        return False
    stat = os.stat(fname)
    ref_stat = os.stat(ref)
    return stat.st_mtime > ref_stat.st_mtime


@task
def deps_png(c):
    dotf = "docs/deps.dot"
    pngf = "docs/deps.png"
    if not is_newer(pngf, dotf):
        c.run(f"dot -Tpng -o {pngf} {dotf}")

@task
def requirements(c):
    inf = "requirements.in"
    outf = "requirements.txt"
    if is_newer(inf, outf):
        c.run(f"pip-compile {inf}")

    dev_inf = "requirements-dev.in"
    dev_outf = "requirements-dev.txt"
    if is_newer(dev_inf, dev_outf) or is_newer(inf, dev_outf):
        c.run(f"pip-compile {dev_inf}")
