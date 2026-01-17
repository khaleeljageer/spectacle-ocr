#!/usr/bin/env bash

CR=$(printf '\r')
KEEP_INPUT=false
IMAGE=""

# Select language packs for Tesseract
LANG="tam_new+eng" # Default language is English, you can modify this line like "eng+deu" for English and German etc.

# Cleanup function to remove temp and possibly original image
cleanup() {
  rm -f "$RESIZED"
  rm -f "$OCR_STDOUT" "$OCR_STDERR"
  if [ -n "$IMAGE" ] && [ "$KEEP_INPUT" = false ]; then
    case "$IMAGE" in
      /tmp/*) rm -f "$IMAGE" ;;
    esac
  fi
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    -k|--keep)
      KEEP_INPUT=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      notify-send -i dialog-error "OCR Error" "Unknown option: $1"
      exit 1
      ;;
    *)
      IMAGE="$1"
      shift
      break
      ;;
  esac
done

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
  notify-send -i dialog-error "OCR Error" "No image file received"
  exit 1
fi

# Resize for better OCR
RESIZED="/tmp/ocr_resized_$$.png"
if command -v magick >/dev/null 2>&1; then
  magick "$IMAGE" -resize 400% "$RESIZED"
elif command -v convert >/dev/null 2>&1; then
  convert "$IMAGE" -resize 400% "$RESIZED"
else
  notify-send -i dialog-error "OCR Error" "ImageMagick not found (need 'magick' or 'convert')"
  exit 1
fi

# Perform OCR
OCR_STDOUT="$(mktemp /tmp/ocr_stdout_XXXXXX.txt)"
OCR_STDERR="$(mktemp /tmp/ocr_stderr_XXXXXX.txt)"
if ! tesseract --psm 6 -l "$LANG" "$RESIZED" - >"$OCR_STDOUT" 2>"$OCR_STDERR"; then
  OCR_OUTPUT="$(cat "$OCR_STDERR")"
  notify-send -i dialog-error "OCR Error" "Tesseract failed: $OCR_OUTPUT"
  exit 1
fi

OCR_OUTPUT="$(cat "$OCR_STDOUT")"

# Normalize line endings
TEXT=$(echo "$OCR_OUTPUT" | sed "s/\$/${CR}/")

# Copy to clipboard
if command -v wl-copy &>/dev/null; then
  echo -n "$TEXT" | wl-copy
elif command -v xclip &>/dev/null; then
  echo -n "$TEXT" | xclip -selection clipboard
else
  notify-send -i dialog-error "OCR Error" "No clipboard tool found"
  exit 1
fi

# Notify success
notify-send -i edit-paste "OCR" "Text copied to clipboard"
