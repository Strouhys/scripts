from __future__ import annotations

import argparse
import logging
import os
import shutil
import sys
from datetime import datetime, timedelta
from pathlib import Path


DEFAULT_ENV_FILE = ".env"


def load_env_file(env_path: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    if not env_path.exists():
        raise FileNotFoundError(f"Konfiguracni soubor neexistuje: {env_path}")

    for line_number, raw_line in enumerate(env_path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if "=" not in line:
            raise ValueError(f"Neplatny radek v .env souboru ({line_number}): {raw_line}")

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if not key:
            raise ValueError(f"Prazdny nazev promenne v .env souboru ({line_number})")

        values[key] = value

    return values


def get_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default

    return value.strip().lower() in {"1", "true", "yes", "y", "ano"}


def setup_logging(log_file: Path) -> None:
    log_file.parent.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_file, encoding="utf-8"),
        ],
    )


def resolve_unique_target(target_path: Path) -> Path:
    if not target_path.exists():
        return target_path

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    candidate = target_path.with_name(f"{target_path.stem}_{timestamp}{target_path.suffix}")
    counter = 1

    while candidate.exists():
        candidate = target_path.with_name(f"{target_path.stem}_{timestamp}_{counter}{target_path.suffix}")
        counter += 1

    return candidate


def move_old_logs(
    source_dir: Path,
    target_dir: Path,
    file_pattern: str,
    min_age_hours: float,
    dry_run: bool,
) -> tuple[int, int]:
    if not source_dir.exists():
        raise FileNotFoundError(f"Zdrojova slozka neexistuje: {source_dir}")

    if not source_dir.is_dir():
        raise NotADirectoryError(f"Zdrojova cesta neni slozka: {source_dir}")

    target_dir.mkdir(parents=True, exist_ok=True)

    cutoff = datetime.now() - timedelta(hours=min_age_hours)
    scanned = 0
    moved = 0

    logging.info("Zdroj: %s", source_dir)
    logging.info("Cil: %s", target_dir)
    logging.info("Maska souboru: %s", file_pattern)
    logging.info("Presouvam soubory starsi nez %.2f hodin, tedy upravene pred: %s", min_age_hours, cutoff)
    logging.info("Dry-run rezim: %s", "ANO" if dry_run else "NE")

    for source_file in sorted(source_dir.glob(file_pattern)):
        if not source_file.is_file():
            continue

        scanned += 1
        modified_at = datetime.fromtimestamp(source_file.stat().st_mtime)

        if modified_at > cutoff:
            logging.info("Preskakuji mladsi soubor: %s (upraveno: %s)", source_file.name, modified_at)
            continue

        target_file = resolve_unique_target(target_dir / source_file.name)

        if dry_run:
            logging.info("DRY-RUN: presunul bych %s -> %s", source_file, target_file)
            moved += 1
            continue

        try:
            shutil.move(str(source_file), str(target_file))
            moved += 1
            logging.info("Presunuto: %s -> %s", source_file, target_file)
        except Exception:
            logging.exception("Chyba pri presunu souboru: %s", source_file)

    logging.info("Hotovo. Zkontrolovano souboru: %d, presunuto: %d", scanned, moved)
    return scanned, moved


def main() -> int:
    parser = argparse.ArgumentParser(description="Presun log souboru starsich nez zadany pocet hodin.")
    parser.add_argument("--env", default=DEFAULT_ENV_FILE, help="Cesta ke konfiguracnimu .env souboru.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    env_path = Path(args.env)
    if not env_path.is_absolute():
        env_path = script_dir / env_path

    try:
        config = load_env_file(env_path)

        source_dir = Path(config["SOURCE_DIR"])
        target_dir = Path(config["TARGET_DIR"])
        file_pattern = config.get("FILE_PATTERN", "*.log")
        min_age_hours = float(config.get("MIN_AGE_HOURS", "24"))
        dry_run = get_bool(config.get("DRY_RUN"), default=False)

        log_file_value = config.get("JOB_LOG_FILE", "logs/move_old_logs.log")
        log_file = Path(log_file_value)
        if not log_file.is_absolute():
            log_file = script_dir / log_file

        setup_logging(log_file)
        logging.info("Start jobu: %s", datetime.now())
        logging.info("Konfigurace: %s", env_path)

        move_old_logs(source_dir, target_dir, file_pattern, min_age_hours, dry_run)
        return 0

    except KeyError as exc:
        print(f"Chybi povinna promenna v .env souboru: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        logging.exception("Job skoncil chybou: %s", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
