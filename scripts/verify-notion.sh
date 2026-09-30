#!/bin/bash
# Notion 토큰/DB ID 사전 점검 + Data Source ID 출력. jq 필요.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a; source <(grep -Ev '^[[:space:]]*(#|$)' .env); set +a
fi
command -v jq >/dev/null || { echo "jq 가 없다: brew install jq"; exit 1; }
: "${NOTION_TOKEN:?NOTION_TOKEN 없음}"
: "${NOTION_DB_ID:?NOTION_DB_ID 없음}"

DB_ID="${NOTION_DB_ID//-/}"

echo "── 1. DB 접근 확인 (Notion-Version 2022-06-28)"
RESP=$(curl -sS "https://api.notion.com/v1/databases/${DB_ID}" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Notion-Version: 2022-06-28")

if [ "$(echo "$RESP" | jq -r '.object')" = "error" ]; then
  echo "  ✗ $(echo "$RESP" | jq -r '.code + ": " + .message')"
  echo "    → 403/404 면 Notion DB 페이지 우상단 ⋯ > Connections 에서 integration 을 Connect 했는지 확인."
  exit 1
fi
echo "  ✓ $(echo "$RESP" | jq -r '.title[0].plain_text // "(제목 없음)"')"

echo
echo "── 2. 필수 property 점검"
PROPS=$(echo "$RESP" | jq -r '.properties | to_entries[] | "\(.key)\t\(.value.type)"')
echo "$PROPS" | sed 's/^/     /'
MISSING=0
while IFS=$'\t' read -r name type; do
  if echo "$PROPS" | awk -F'\t' -v n="$name" -v t="$type" '$1==n && $2==t{f=1} END{exit !f}'; then
    :
  else
    echo "  ✗ 없음/타입 불일치: ${name} (${type})"
    MISSING=1
  fi
done <<'REQ'
Title	title
Category	select
Level	select
Date	date
Day	select
Tags	multi_select
Status	select
REQ
[ "$MISSING" -eq 0 ] && echo "  ✓ 필수 property 7개 모두 존재"

echo
echo "── 3. Data Source ID 조회 (Notion-Version 2025-09-03)"
DS=$(curl -sS "https://api.notion.com/v1/databases/${DB_ID}" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Notion-Version: 2025-09-03" | jq -r '.data_sources[0].id // empty')

if [ -n "$DS" ]; then
  echo "  ✓ NOTION_DS_ID=${DS}"
  echo "    → .env 와 GitHub Secrets 에 이 값을 넣어라."
else
  echo "  ! data_sources 가 안 나온다. 이 경우 DB ID 를 그대로 DS_ID 로 써도 대개 동작한다:"
  echo "    NOTION_DS_ID=${DB_ID}"
fi
