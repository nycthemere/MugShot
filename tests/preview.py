#!/usr/bin/env python3
"""
MugShot — Live UI Preview Launcher

Cherche Love2D localement ou dans le système.
Si nécessaire, télécharge Love2D 11.5 pour :
- Windows x86_64
- Linux x86_64
- macOS

Ajoute les certificats de certifi lorsqu'il est installé.
La vérification HTTPS reste activée.

Les archives ZIP sont supprimées après extraction.
Les fichiers Lua du dossier preview doivent déjà être présents.
"""

from pathlib import Path
from urllib.request import Request, urlopen
import os
import platform
import shutil
import ssl
import stat
import subprocess
import sys
import tempfile
import zipfile

try:
    import certifi
except ImportError:
    certifi = None


ROOT = Path(__file__).resolve().parent
PREVIEW_DIR = ROOT / "preview"

WINDOWS_URL = (
    "https://github.com/love2d/love/releases/download/"
    "11.5/love-11.5-win64.zip"
)

LINUX_URL = (
    "https://github.com/love2d/love/releases/download/"
    "11.5/love-11.5-x86_64.AppImage"
)

MACOS_URL = (
    "https://github.com/love2d/love/releases/download/"
    "11.5/love-11.5-macos.zip"
)


def find_love_binary() -> Path | None:
    """Chercher Love2D sans rien télécharger."""

    # AppImage Linux dans preview/ ou à côté du script.
    if sys.platform.startswith("linux"):
        for directory in (PREVIEW_DIR, ROOT):
            matches = sorted(
                path
                for path in directory.iterdir()
                if path.is_file()
                and path.name.lower().startswith("love")
                and path.suffix.lower() == ".appimage"
            )

            if matches:
                return matches[0]

    # Application macOS locale ou installée.
    if sys.platform == "darwin":
        candidates = [
            PREVIEW_DIR / "love.app/Contents/MacOS/love",
            ROOT / "love.app/Contents/MacOS/love",
            Path("/Applications/love.app/Contents/MacOS/love"),
            Path.home() / "Applications/love.app/Contents/MacOS/love",
        ]

        for path in candidates:
            if path.is_file():
                return path

    # Version portable dans preview/.
    patterns = (
        ["love.exe", "love*/love.exe"]
        if sys.platform == "win32"
        else ["love", "love*/love"]
    )

    for pattern in patterns:
        for path in sorted(PREVIEW_DIR.glob(pattern), reverse=True):
            if path.is_file():
                return path

    # Installation Windows.
    if sys.platform == "win32":
        for variable in (
            "ProgramFiles",
            "ProgramFiles(x86)",
            "LOCALAPPDATA",
        ):
            base = os.environ.get(variable)

            if not base:
                continue

            executable = Path(base) / "LOVE" / "love.exe"

            if executable.is_file():
                return executable

    # Installation accessible dans le PATH.
    path = shutil.which("love")
    return Path(path) if path else None


def create_ssl_context() -> ssl.SSLContext:
    """Conserver les certificats système et ajouter ceux de certifi."""
    context = ssl.create_default_context()

    if certifi is not None:
        context.load_verify_locations(cafile=certifi.where())

    return context


def download_file(url: str, destination: Path) -> None:
    """Télécharger dans un fichier temporaire avant de le renommer."""
    print(f"[+] Téléchargement : {destination.name}")

    request = Request(
        url,
        headers={"User-Agent": "MugShot-Preview-Launcher/1.0"},
    )

    context = create_ssl_context()
    temporary_path = None

    try:
        with tempfile.NamedTemporaryFile(
            dir=destination.parent,
            suffix=".part",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)

            with urlopen(
                request,
                timeout=60,
                context=context,
            ) as response:
                shutil.copyfileobj(response, temporary)

        if temporary_path.stat().st_size == 0:
            raise RuntimeError("Le fichier téléchargé est vide.")

        temporary_path.replace(destination)

    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def extract_windows_archive(archive: Path) -> None:
    """Extraire l'archive Windows en vérifiant les chemins."""
    destination = PREVIEW_DIR.resolve()

    with zipfile.ZipFile(archive) as zip_file:
        for member in zip_file.infolist():
            target = (destination / member.filename).resolve()

            if not target.is_relative_to(destination):
                raise RuntimeError(
                    "L'archive contient un chemin non autorisé."
                )

        zip_file.extractall(destination)


def download_love() -> Path:
    """Télécharger et préparer Love2D pour le système actuel."""

    # macOS : extraction du bundle avec l'outil système ditto.
    if sys.platform == "darwin":
        executable = PREVIEW_DIR / "love.app/Contents/MacOS/love"

        with tempfile.TemporaryDirectory(
            prefix="love-download-",
            dir=PREVIEW_DIR,
        ) as temporary:
            archive = Path(temporary) / "love-11.5-macos.zip"
            download_file(MACOS_URL, archive)

            print("[+] Extraction de Love2D pour macOS...")

            result = subprocess.run(
                [
                    "/usr/bin/ditto",
                    "-x",
                    "-k",
                    str(archive),
                    str(PREVIEW_DIR),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
                errors="replace",
            )

            if result.returncode != 0:
                raise RuntimeError(
                    result.stderr.strip()
                    or "Impossible d'extraire Love2D pour macOS."
                )

        if not executable.is_file():
            raise RuntimeError(
                "L'exécutable love.app/Contents/MacOS/love "
                "est introuvable après extraction."
            )

        return executable

    if sys.platform != "win32" and not sys.platform.startswith("linux"):
        raise RuntimeError(
            "Téléchargement automatique disponible uniquement "
            "pour Windows, Linux et macOS."
        )

    # Les téléchargements Windows et Linux configurés sont en x86_64.
    architecture = platform.machine().lower()

    if architecture not in ("x86_64", "amd64"):
        raise RuntimeError(
            f"Téléchargement automatique non prévu pour {architecture}. "
            "Installe une version de Love2D adaptée à ton système."
        )

    # Linux : l'AppImage ne nécessite pas d'extraction.
    if sys.platform.startswith("linux"):
        executable = PREVIEW_DIR / "love-11.5-x86_64.AppImage"
        download_file(LINUX_URL, executable)
        return executable

    # Windows : extraire puis supprimer le ZIP temporaire.
    with tempfile.TemporaryDirectory(
        prefix="love-download-",
        dir=PREVIEW_DIR,
    ) as temporary:
        archive = Path(temporary) / "love-11.5-win64.zip"
        download_file(WINDOWS_URL, archive)

        print("[+] Extraction de Love2D pour Windows...")
        extract_windows_archive(archive)

    executable = PREVIEW_DIR / "love-11.5-win64" / "love.exe"

    if not executable.is_file():
        raise RuntimeError(
            "love.exe est introuvable après extraction."
        )

    return executable


def main() -> int:
    try:
        # Le téléchargement fournit Love2D, pas les fichiers du projet.
        if not (PREVIEW_DIR / "main.lua").is_file():
            raise RuntimeError(
                f"Fichier introuvable : {PREVIEW_DIR / 'main.lua'}\n"
                "Restaure le dossier preview du projet avant de lancer."
            )

        love_binary = find_love_binary()

        if love_binary is None:
            print("[-] Love2D introuvable. Installation automatique...")

            if certifi is None:
                print(
                    "[i] certifi absent : utilisation des certificats "
                    "système uniquement."
                )

            love_binary = download_love()

        # Autoriser l'exécution de l'AppImage pour son propriétaire.
        if (
            sys.platform.startswith("linux")
            and love_binary.suffix.lower() == ".appimage"
        ):
            love_binary.chmod(
                love_binary.stat().st_mode | stat.S_IXUSR
            )

        print(f"[+] Love2D : {love_binary}")
        print(f"[+] Lancement du preview : {PREVIEW_DIR}")

        subprocess.Popen(
            [str(love_binary), str(PREVIEW_DIR)],
            cwd=PREVIEW_DIR,
            close_fds=True,
        )

        return 0

    except (
        OSError,
        RuntimeError,
        ValueError,
        zipfile.BadZipFile,
    ) as error:
        print(f"[-] Erreur : {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())