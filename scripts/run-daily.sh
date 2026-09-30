#!/bin/bash
# CS Daily 실행. 로컬(맥)과 GitHub Actions 양쪽에서 동작한다.
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p logs

# .env 로드 (로컬용. CI 에서는 env/secrets 로 이미 주입됨)
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# 사후 검증 단계에서 필요하다. 없으면 검증이 조용히 건너뛰어지므로 여기서 막는다.
command -v jq >/dev/null || { echo "jq 가 없다: brew install jq (CI 러너에는 기본 설치돼 있다)"; exit 1; }

: "${NOTION_TOKEN:?NOTION_TOKEN 이 없다. .env 또는 secrets 확인}"
: "${NOTION_DB_ID:?NOTION_DB_ID 가 없다. .env 또는 secrets 확인}"
: "${NOTION_DS_ID:?NOTION_DS_ID 가 없다. scripts/verify-notion.sh 로 확인하고 채워라}"

export TZ=Asia/Seoul
TODAY=$(date +%Y-%m-%d)
DOW_NUM=$(date +%u)                       # 1=월 ... 7=일
DOW_KO=$(echo "월 화 수 목 금 토 일" | cut -d' ' -f"$DOW_NUM")
LOG_FILE="logs/daily_$(date +%Y%m%d_%H%M%S).log"

MODE="${1:-daily}"                        # daily | weekly
PROMPT_FILE="prompts/daily.md"
[ "$MODE" = "weekly" ] && PROMPT_FILE="prompts/weekly.md"

# 주말 기본 동작: daily 를 돌리지 않는다 (인자로 강제하면 돈다)
if [ "$MODE" = "daily" ] && [ "$DOW_NUM" -ge 6 ] && [ -z "${FORCE:-}" ]; then
  echo "[$TODAY $DOW_KO] 주말이라 skip. 강제 실행은 FORCE=1." | tee -a "$LOG_FILE"
  exit 0
fi

echo "[$TODAY $DOW_KO] CS Daily 시작 (mode=$MODE)" | tee -a "$LOG_FILE"

# 프롬프트 + 런타임 컨텍스트(날짜/ID)를 합쳐서 헤드리스 Claude 에 파이프
{
  cat "$PROMPT_FILE"
  cat <<CTX

---

## 런타임 컨텍스트 (스크립트가 주입한 값 — 추측하지 말고 이 값을 써라)

- 오늘 (KST): **${TODAY}**
- 요일: **${DOW_KO}**
- Notion DB ID: \`${NOTION_DB_ID}\`
- Notion Data Source ID: \`${NOTION_DS_ID}\`
- Data Source URL (notion-search 의 data_source_url 인자): \`collection://${NOTION_DS_ID}\`
CTX
} | claude -p \
  --mcp-config .mcp.json \
  --allowed-tools "mcp__notion__*,Read" \
  --permission-mode acceptEdits \
  --output-format text \
  2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

# claude -p 는 인증 실패(크레딧 부족 등)에도 0 을 반환한다. 그래서 종료코드만
# 믿으면 CI 가 조용히 초록불이 된다. Notion DB 에 오늘 자 페이지가 실제로
# 생겼는지를 성공의 기준으로 삼는다 — DB 가 진도의 단일 출처라는 원칙과도 맞다.
if [ "$EXIT_CODE" -eq 0 ]; then
  RESP=$(curl -sS -X POST "https://api.notion.com/v1/data_sources/${NOTION_DS_ID}/query" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: 2025-09-03" \
    -H "content-type: application/json" \
    -d "{\"filter\":{\"property\":\"Date\",\"date\":{\"equals\":\"${TODAY}\"}},\"page_size\":10}")

  if [ "$(echo "$RESP" | jq -r '.object')" = "error" ]; then
    echo "  ✗ 사후 검증 실패: $(echo "$RESP" | jq -r '.code + ": " + .message')" | tee -a "$LOG_FILE"
    EXIT_CODE=1
  else
    CREATED=$(echo "$RESP" | jq -r '.results | length')
    EXPECTED=2
    [ "$MODE" = "weekly" ] && EXPECTED=1
    if [ "$CREATED" -lt "$EXPECTED" ]; then
      echo "  ✗ 오늘($TODAY) 자 페이지가 ${CREATED}개뿐이다 (기대 ${EXPECTED}개). 위 로그에서 원인을 확인해라." | tee -a "$LOG_FILE"
      EXIT_CODE=1
    else
      echo "  ✓ 오늘($TODAY) 자 페이지 ${CREATED}개 확인" | tee -a "$LOG_FILE"
    fi
  fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 종료 (exit=$EXIT_CODE)" | tee -a "$LOG_FILE"
exit "$EXIT_CODE"
