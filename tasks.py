
import os
from configparser import ConfigParser
from invoke import task

CONSTANTS_PATH = "src/constants.gd"
PRESETS_PATH = "export_presets.cfg"
CREDS_PATH = ".godot/export_credentials.cfg"


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


def _make_path(path_template, version_name):
    base, ext = os.path.splitext(path_template)
    base, _ = base.rsplit("-", 1)
    return f"{base}-{version_name}{ext}"

def _load_credentials():
    creds = {}
    if os.path.isfile(CREDS_PATH):
        parser = ConfigParser()
        parser.read(CREDS_PATH)
        sect = "preset.0.options"
        creds["path"] = parser[sect]["keystore/debug"]
        creds["user"] = parser[sect]["keystore/debug_user"]
        creds["password"] = parser[sect]["keystore/debug_password"]
    elif "REV_KEYSTORE_PATH" in os.environ:
        # look in env vars
        creds["path"] = os.environ["REV_KEYSTORE_PATH"]
        creds["user"] = os.environ["REV_KEYSTORE_USER"]
        creds["password"] = os.environ["REV_KEYSTORE_PASSWORD"]
    else:
        raise RuntimeError("Can't find keystore credentials "
                            "for signing Android packages!")
    return creds


def _get_version():
    version_name = None
    version_code = None
    for line in open(CONSTANTS_PATH, "rt"):
        if line.startswith("const VERSION_CODE"):
            version_code = line.strip().split(" ")[-1]
        elif line.startswith("const VERSION"):
            version_name = line.strip().split(" ")[-1]
    assert version_name and version_code
    return version_name, version_code


@task
def make_export_presets(c):
    """ Generate a presets file that Godot can use to produce Android builds. """
    version_name, version_code = _get_version()
    parser = ConfigParser()
    parser.read(PRESETS_PATH + ".in")
    creds = _load_credentials()
    
    for sect in ["preset.0", "preset.1"]:
        old_path = parser[sect]["export_path"]
        parser[sect]["export_path"] = _make_path(old_path, version_name)

    for sect in ["preset.0.options", "preset.1.options"]:
        parser[sect]["version/code"] = str(version_code)
        parser[sect]["version/name"] = f'"{version_name}"'

        # credenditals
        for mode in ["debug", "release"]:
            parser[sect][f"keystore/{mode}"] = creds["path"]
            parser[sect][f"keystore/{mode}_user"] = creds["user"]
            parser[sect][f"keystore/{mode}_password"] = creds["password"]

    parser.write(open(PRESETS_PATH, "wt"), False)
