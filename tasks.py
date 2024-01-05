
import os
from configparser import ConfigParser
from invoke import task

CONSTANTS_PATH = "src/constants.gd"
PRESETS_PATH = "export_presets.cfg"
CREDS_PATH = ".godot/export_credentials.cfg"
GODOT_SETTINGS = os.path.expanduser("~/.config/godot/editor_settings-4.tres")


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
    assert "X.Y.Z" in path_template
    return path_template.replace("X.Y.Z", version_name)


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
            version_name = line.strip().split(" ")[-1].strip('"')
    assert version_name and version_code
    return version_name, version_code


@task
def make_export_presets(c, signed=True):
    """ Generate a presets file that Godot can use to produce Android builds. """
    version_name, version_code = _get_version()
    parser = ConfigParser()
    parser.read(PRESETS_PATH + ".in")
    if signed:
        creds = _load_credentials()
    
    for sect in ["preset.0", "preset.1", "preset.2"]:
        old_path = parser[sect]["export_path"]
        parser[sect]["export_path"] = _make_path(old_path, version_name)

    for sect in ["preset.0.options", "preset.1.options"]:
        parser[sect]["version/code"] = str(version_code)
        parser[sect]["version/name"] = f'"{version_name}"'

        # credenditals
        for mode in ["debug", "release"]:
            if signed:
                parser[sect]["package/signed"] = "true"
                parser[sect][f"keystore/{mode}"] = creds["path"]
                parser[sect][f"keystore/{mode}_user"] = creds["user"]
                parser[sect][f"keystore/{mode}_password"] = creds["password"]
            else:
                parser[sect]["package/signed"] = "false"

    parser.write(open(PRESETS_PATH, "wt"), False)


@task
def make_fdroid_presets(c, godot_src_dir):
    """ Generate a presets file that Godot can use to produce unsigned Android builds 
    for F-Droid. """
    version_name, version_code = _get_version()
    parser = ConfigParser()
    parser.read(PRESETS_PATH + ".in")
    templates = os.path.join(godot_src_dir, "bin", "android_release.apk")
    
    for sect in ["preset.0", "preset.1"]:
        old_path = parser[sect]["export_path"]
        parser[sect]["export_path"] = _make_path(old_path, version_name)

    for sect in ["preset.0.options", "preset.1.options"]:
        parser[sect]["version/code"] = str(version_code)
        parser[sect]["version/name"] = f'"{version_name}"'
        parser[sect]["custom_template/release"] = f'"{templates}"'
        parser[sect]["package/signed"] = "false"
        parser[sect]["gradle_build/use_gradle_build"] = "false"
        parser[sect]["gradle_build/min_sdk"] = '""'

    parser.write(open(PRESETS_PATH, "wt"), False)


def _find_godot(context):
    for name in ["godot4", "godot"]:
        if context.run(f"which {name}", warn=True).return_code == 0:
            return name
    if "GODOT" in os.environ:
        return os.environ["GODOT"]
    else:
        raise RuntimeError("Can't find Godot binary. " 
                           "Consider linking it to `godot4` or defining "
                           "the GODOT environment variable.")


@task(make_export_presets)
def build_android(c):
    """ Make the two android package formats from the current sources. """
    # Ex.: godot --export-release 'Android APK' bin/revengate.apk
    godot = _find_godot(c)
    
    parser = ConfigParser()
    parser.read(PRESETS_PATH)
    for sect in ["preset.0", "preset.1"]:
        name = parser[sect]["name"]
        path = parser[sect]["export_path"]
        assert name.lstrip('"\'').startswith("Android")
        cmd = f"{godot} --headless --export-release {name} {path}"
        res = c.run(cmd, echo=True)
        assert res.return_code == 0


@task(make_export_presets)
def build_web(c):
    """ Make a zip file with the HTML5 flavour of the game. """
    # Ex.: godot --export-release 'Web' bin/revengate.apk
    godot = _find_godot(c)
    
    parser = ConfigParser()
    parser.read(PRESETS_PATH)
    sect = "preset.2"
    name = parser[sect]["name"]
    path = parser[sect]["export_path"].strip('"')
    assert name.lstrip('"\'').startswith("Web")

    base_dir = os.path.split(path)[0]
    os.makedirs(base_dir, exist_ok=True)

    cmd = f"{godot} --headless --export-release {name} {path}"
    res = c.run(cmd, echo=True)
    assert res.return_code == 0

    pack_path = base_dir.rstrip("/") + ".zip"
    if os.path.isfile(pack_path):
        os.unlink(pack_path)

    res = c.run(f"zip -r {pack_path} {base_dir}", echo=True)
    assert res.return_code == 0
    
    print(f"Saved HTML5 export pack to {pack_path}")


@task 
def configure_android_sdk(c, sdk_path):
    """Save the path to the Android SDK in the Godot settings"""
    # FIXME: this is not needed anymore with Godot 4.2+
    # Doing this here because the path is full of '/' chars and that confuses sed
    assert os.path.isdir(sdk_path)
    # can't use ConfigParser for this one becase the tres dialect is weird
    new_lines = []
    for line in open(GODOT_SETTINGS, "rt"):
        if line.startswith("export/android/android_sdk_path"):
            line = f'export/android/android_sdk_path = "{sdk_path}"\n'
        new_lines.append(line)
    open(GODOT_SETTINGS, "wt").writelines(new_lines)


@task
def migrate_legacy_asset(c, old_path, new_path):
    """ Move an asset from the legacy Python codebase to the new Godot one, 
    leave a symlink in the old location. """
    print(f"migrate_legacy_asset: {old_path=} {new_path=}")
    assert old_path != new_path
    assert os.path.isfile(old_path) and not os.path.islink(old_path)
    assert not os.path.isabs(old_path)
    basedir, fname = os.path.split(old_path)
    if not new_path:
        new_path = fname
    elif os.path.isdir(new_path):
        new_path = os.path.join(new_path, fname)
    assert not os.path.isabs(new_path)
    if os.path.isfile(new_path):
        assert os.path.islink(new_path)
        os.unlink(new_path)
    
    c.run(f"git mv {old_path} {new_path}")
    os.chdir(basedir)
    depth = len(basedir.split(os.path.sep))
    rel_new = os.path.join(*[".."]*depth, new_path)
    os.symlink(rel_new, fname)
    c.run(f"git add {fname}")
