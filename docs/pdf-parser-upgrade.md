# PDF Parser Upgrade

This branch records the next parser upgrade checkpoint for the billing PDF import flow.

## Goal

Improve the PDF table parsing structure so future billing imports can extract weight-slip rows more reliably.

## Scope

- Keep the PDF parsing work isolated from unrelated billing UI changes.
- Document the intended parsing direction before adding deeper production parsing logic.
- Prepare this branch for review through a pull request.

## Next implementation target

Parse real weight values from PDF/OCR table text, including gross, tare, and net values when available.
