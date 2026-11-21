#!/usr/bin/env bash
# ตัวติดตั้งเทมเพลต KP Studio PRISM (ไม่ต้องใช้โทเค็น)
# นักเรียนกรอกใน RunPod Template: KP_USER (ชื่อผู้ใช้) และ KP_PASS (รหัสผ่าน) ที่ครูผิงให้
R="${KP_DIST_REPO:-salineeprog/kp-dist-prism}"
fail(){ echo ""; echo "❌ $1"; echo "   ติดต่อครูผิงเพื่อตรวจสอบบัญชี (พอดยังเปิดอยู่ — ปิดพอดเองเพื่อหยุดค่าใช้จ่าย)"; sleep infinity; }
[ -n "$KP_USER" ] && [ -n "$KP_PASS" ] || fail "ยังไม่ได้กรอก KP_USER / KP_PASS ในเทมเพลต"
command -v openssl >/dev/null && command -v python3 >/dev/null || { apt-get update -qq && apt-get install -y -qq openssl python3 curl >/dev/null; } || fail "ติดตั้ง openssl ไม่สำเร็จ"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
get(){ curl -fsSL -H "Accept: application/vnd.github.raw" "${KP_GH_API:-https://api.github.com}/repos/$R/contents/$1" -o "$T/$1" \
       || curl -fsSL "https://raw.githubusercontent.com/$R/main/$1" -o "$T/$1"; }
echo "⬇️  กำลังดาวน์โหลดชุดติดตั้ง..."
get keys.json && get kp.enc || fail "ดาวน์โหลดชุดติดตั้งไม่สำเร็จ (เช็คอินเทอร์เน็ตของพอด)"
U=$(printf '%s' "$KP_USER" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')
H=$(printf '%s' "$U" | sha256sum | cut -c1-16)
read -r WUK WK EXP < <(python3 - "$T/keys.json" "$H" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["users"].get(sys.argv[2])
print(e["wuk"], e["wk"], e.get("exp","-") or "-") if e else print("- - -")
PY
)
[ "$WUK" != "-" ] || fail "ไม่พบชื่อผู้ใช้ $KP_USER (ชื่อผิด หรือบัญชีถูกปิดแล้ว)"
export P="$U:$KP_PASS"
UK=$(printf '%s' "$WUK" | openssl enc -d -aes-256-cbc -pbkdf2 -md sha256 -iter 600000 -pass env:P -a -A 2>/dev/null) || fail "รหัสผ่านไม่ถูกต้อง"
export P="$UK"
K=$(printf '%s' "$WK" | openssl enc -d -aes-256-cbc -pbkdf2 -md sha256 -iter 10000 -pass env:P -a -A 2>/dev/null) || fail "กุญแจไม่ตรง (ครูผิงอาจเพิ่งอัปเดต ลองรีสตาร์ทพอดอีกครั้ง)"
export P="$K"
mkdir -p /opt/kp-studio
openssl enc -d -aes-256-cbc -pbkdf2 -md sha256 -iter 10000 -pass env:P -in "$T/kp.enc" | tar -xz -C /opt/kp-studio || fail "แตกไฟล์ชุดติดตั้งไม่สำเร็จ"
unset P UK K
echo "✅ ยืนยันบัญชี $KP_USER แล้ว (หมดอายุ: $EXP)"
exec bash /opt/kp-studio/start.sh
