"""Usage: python render_images.py <folder-or-file.html> [...] [--only name ...] [--out <dir>]

Renders diagram and chart sources (HTML with inline SVG) to PNG with headless Microsoft Edge (or Chrome). Each source
declares its canvas with <meta name="render-size" content="WIDTHxHEIGHT">. A folder renders every *.html in it. The
PNG goes next to the source's folder when that folder is called src/ (docs/diagrams/src/x.html -> docs/diagrams/x.png),
otherwise next to the source; --out puts all PNGs in one folder. --only renders just the named sources (without .html).
Part of the netmedia-document plugin (netmedia-document:diagram)."""
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]


def browser():
    for candidate in BROWSERS + [shutil.which(n) or "" for n in ("msedge", "google-chrome", "chromium", "chrome")]:
        if candidate and Path(candidate).exists():
            return candidate
    sys.exit("No Edge or Chrome found.")


def target_for(source, out):
    if out:
        return Path(out) / (source.stem + ".png")
    folder = source.parent.parent if source.parent.name == "src" else source.parent
    return folder / (source.stem + ".png")


def render(exe, source, out=None):
    match = re.search(r'name="render-size" content="(\d+)x(\d+)"', source.read_text(encoding="utf-8"))
    if not match:
        sys.exit(f"{source.name}: no <meta name=\"render-size\" content=\"WxH\">")
    width, height = match.groups()
    target = target_for(source, out)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as profile:
        subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                        f"--user-data-dir={profile}", "--force-device-scale-factor=1", "--virtual-time-budget=2000",
                        f"--window-size={width},{height}", f"--screenshot={target.resolve()}",
                        source.resolve().as_uri()],
                       check=True, capture_output=True, timeout=60)
    print(f"{target}  {width}x{height}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sources", nargs="+")
    parser.add_argument("--only", nargs="*", default=[])
    parser.add_argument("--out")
    args = parser.parse_args()
    exe = browser()
    for item in map(Path, args.sources):
        for source in (sorted(item.glob("*.html")) if item.is_dir() else [item]):
            if not args.only or source.stem in args.only:
                render(exe, source, args.out)


if __name__ == "__main__":
    main()
