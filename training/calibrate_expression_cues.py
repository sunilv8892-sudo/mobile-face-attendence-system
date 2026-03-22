from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

import pandas as pd


LABELS = ["Angry", "Disgust", "Happy", "Neutral", "Sad", "Surprise"]


@dataclass
class CueCalibration:
    happy_smile_threshold: float = 0.58
    happy_mouth_open_max: float = 0.11
    surprise_mouth_open_min: float = 0.09
    surprise_eye_open_min: float = 0.40
    disgust_eye_open_max: float = 0.32
    disgust_mouth_open_max: float = 0.08
    neutral_smile_max: float = 0.42
    neutral_mouth_open_max: float = 0.05
    neutral_eye_open_min: float = 0.35
    softmax_temperature: float = 0.75

    happy_smile_weight: float = 0.72
    happy_mouth_weight: float = 0.28
    surprise_mouth_weight: float = 0.74
    surprise_eye_weight: float = 0.16
    surprise_smile_penalty: float = 0.10
    disgust_eye_weight: float = 0.46
    disgust_mouth_weight: float = 0.34
    disgust_smile_penalty: float = 0.20
    neutral_smile_penalty: float = 0.38
    neutral_mouth_penalty: float = 0.34
    neutral_eye_reward: float = 0.28
    sad_smile_penalty: float = 0.44
    sad_eye_penalty: float = 0.30
    sad_mouth_penalty: float = 0.26
    angry_smile_penalty: float = 0.42
    angry_eye_penalty: float = 0.36
    angry_mouth_penalty: float = 0.22


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Calibrate the expression cue thresholds from labeled face samples. "
            "Expected columns: label, smile, left_eye, right_eye, mouth_open, mouth_width"
        )
    )
    parser.add_argument("csv_path", type=Path, help="CSV with labeled cue samples")
    parser.add_argument("--output", type=Path, default=Path("assets/models/expression_cue_calibration.json"))
    parser.add_argument("--label-column", default="label")
    parser.add_argument("--smile-column", default="smile")
    parser.add_argument("--left-eye-column", default="left_eye")
    parser.add_argument("--right-eye-column", default="right_eye")
    parser.add_argument("--mouth-open-column", default="mouth_open")
    parser.add_argument("--mouth-width-column", default="mouth_width")
    return parser.parse_args()


def _quantile(series: pd.Series, q: float, fallback: float) -> float:
    if series.empty:
      return fallback
    return float(series.quantile(q))


def _mean(series: pd.Series, fallback: float) -> float:
    if series.empty:
      return fallback
    return float(series.mean())


def build_calibration(df: pd.DataFrame, args: argparse.Namespace) -> CueCalibration:
    label = args.label_column
    smile = args.smile_column
    left_eye = args.left_eye_column
    right_eye = args.right_eye_column
    mouth_open = args.mouth_open_column
    mouth_width = args.mouth_width_column

    happy = df[df[label].astype(str).str.lower() == "happy"]
    surprise = df[df[label].astype(str).str.lower() == "surprise"]
    disgust = df[df[label].astype(str).str.lower() == "disgust"]
    neutral = df[df[label].astype(str).str.lower() == "neutral"]
    sad = df[df[label].astype(str).str.lower() == "sad"]
    angry = df[df[label].astype(str).str.lower() == "angry"]

    eye_open = (df[left_eye].astype(float) + df[right_eye].astype(float)) / 2.0
    mouth_aspect = df[mouth_open].astype(float) / df[mouth_width].astype(float).replace(0, pd.NA)

    calibration = CueCalibration()
    calibration.happy_smile_threshold = _quantile(happy[smile].astype(float), 0.40, calibration.happy_smile_threshold)
    calibration.happy_mouth_open_max = _quantile(happy[mouth_open].astype(float), 0.60, calibration.happy_mouth_open_max)
    calibration.surprise_mouth_open_min = _quantile(surprise[mouth_open].astype(float), 0.35, calibration.surprise_mouth_open_min)
    calibration.surprise_eye_open_min = _quantile(surprise[left_eye].astype(float).combine(surprise[right_eye].astype(float), max), 0.35, calibration.surprise_eye_open_min)
    calibration.disgust_eye_open_max = _quantile(disgust[[left_eye, right_eye]].mean(axis=1), 0.60, calibration.disgust_eye_open_max)
    calibration.disgust_mouth_open_max = _quantile(disgust[mouth_open].astype(float), 0.65, calibration.disgust_mouth_open_max)
    calibration.neutral_smile_max = _quantile(neutral[smile].astype(float), 0.70, calibration.neutral_smile_max)
    calibration.neutral_mouth_open_max = _quantile(neutral[mouth_open].astype(float), 0.70, calibration.neutral_mouth_open_max)
    calibration.neutral_eye_open_min = _quantile(neutral[[left_eye, right_eye]].mean(axis=1), 0.35, calibration.neutral_eye_open_min)

    calibration.happy_smile_weight = 0.70 + (_mean(happy[smile].astype(float), 0.5) * 0.10)
    calibration.surprise_mouth_weight = 0.70 + (_mean(surprise[mouth_open].astype(float), 0.1) * 0.10)
    calibration.disgust_eye_weight = 0.42 + (1.0 - _mean(disgust[[left_eye, right_eye]].mean(axis=1), 0.5)) * 0.10
    calibration.neutral_eye_reward = 0.22 + (_mean(neutral[[left_eye, right_eye]].mean(axis=1), 0.5) * 0.08)
    calibration.softmax_temperature = 0.70

    return calibration


def main() -> None:
    args = parse_args()
    df = pd.read_csv(args.csv_path)
    missing = [column for column in [args.label_column, args.smile_column, args.left_eye_column, args.right_eye_column, args.mouth_open_column, args.mouth_width_column] if column not in df.columns]
    if missing:
        raise SystemExit(f"Missing required columns: {missing}")

    calibration = build_calibration(df, args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(asdict(calibration), indent=2), encoding="utf-8")
    print(f"Wrote calibration to {args.output}")


if __name__ == "__main__":
    main()