# Ton

Maintainer: **xcold**

This repository provides lightweight CI guardrails for repository hygiene and secret-pattern scanning.

## ตัวโปรแกรมอยู่ที่ไหน?

โปรแกรมหลักอยู่ในโฟลเดอร์ `scripts/`:

- `scripts/run-checks.sh` → รันทุกอย่างในคำสั่งเดียว (แนะนำ)
- `scripts/ci-check.sh` → ตรวจโครงสร้าง repository
- `scripts/security-scan.sh` → สแกนหารูปแบบ secret ที่เสี่ยงสูง

## ใช้งานได้แล้วหรือยัง?

ใช้งานได้แล้ว เมื่อรัน `scripts/run-checks.sh` แล้วผ่านทั้งหมด จะพร้อมสำหรับการอัปโหลด.

## Quick start

```bash
./scripts/run-checks.sh
```

หรือรันแยกทีละตัว:

```bash
./scripts/ci-check.sh
./scripts/security-scan.sh
```

## What is validated

- `README.md` exists, is non-empty, and has a top-level heading.
- Shell scripts in `scripts/` are executable.
- Shell scripts in `scripts/` start with a shebang.
- Common high-signal secret patterns are not present.
