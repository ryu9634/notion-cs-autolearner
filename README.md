# CS Daily — Java/Backend Auto-learner

매일 새벽 5시(KST) GitHub Actions가 Claude Code를 무인 실행해서 Notion DB에 페이지를 자동으로 쌓는다.

- **평일(월~금)**: 자바/백엔드 CS 학습 페이지 2개 (`prompts/daily.md`)
- **주말(토·일)**: 지난 7일간 화제였던 IT 이슈 TOP 10 트렌드 페이지 1개 (`prompts/weekend.md`)

핵심 아이디어는 하나다: **프롬프트를 코드처럼 버전관리하고, 스케줄러가 Claude를 헤드리스로 돌린다.**

```
매일 05:00 KST
  → GitHub Actions cron
  → scripts/run-daily.sh  (요일 보고 평일=daily / 주말=weekend 자동 선택)
  → 프롬프트 + 런타임 컨텍스트(오늘 날짜/DB ID)를 claude -p 로 파이프
  → 평일: Notion DB를 스캔해 진도 판단 → 오늘 주제 2개 선정 → 페이지 생성
  → 주말: 웹 검색으로 지난 7일 IT 화제 수집 → 10개 선정 → 트렌드 페이지 생성
  → 성공하면 til/YYYY/YYYY-MM-DD.md 에 오늘 주제를 기록해 커밋·푸시 (잔디)
```

## 디렉토리

```
cs-daily-java/
├── .env                      # 토큰 (직접 작성, .env.example 참조 / git 제외)
├── .mcp.json                 # Notion MCP 설정
├── curriculum.json           # 8 카테고리 × 기초10/응용10 = 160 주제 마스터 데이터
├── prompts/
│   ├── daily.md              # 평일 프롬프트 (진도 판정 + 페이지 생성 규칙)
│   ├── weekend.md            # 주말 프롬프트 (IT 핫이슈 TOP 10)
│   └── weekly.md             # 주간 요약 프롬프트
├── scripts/
│   ├── run-daily.sh          # 메인 실행기 (로컬/CI 공용)
│   ├── run-weekly.sh         # 주간 요약만 실행
│   └── verify-notion.sh      # Notion 토큰/DB 스키마 점검 + Data Source ID 출력
├── .github/workflows/daily.yml
├── til/                      # 날짜별 학습 기록 (Actions 가 자동 커밋)
└── logs/                     # 실행 로그 (git 제외)
```

## 커리큘럼

| 카테고리 | 가중치 | 기초 | 응용 |
|---|---|---|---|
| ☕ JVM/자바 언어 | high | 10 | 10 |
| 🌱 Spring/프레임워크 | high | 10 | 10 |
| 🗄️ 데이터베이스/JPA | high | 10 | 10 |
| 🧵 동시성/병렬처리 | medium | 10 | 10 |
| 🌐 네트워크/HTTP | medium | 10 | 10 |
| 🏗️ 시스템 설계/아키텍처 | medium | 10 | 10 |
| ⚙️ 운영체제/인프라 | low | 10 | 10 |
| 🔐 보안/인증 | low | 10 | 10 |

하루 2주제 × 평일 → **160주제 ≈ 16주** 분량. 기한은 없다 —
160주제를 다 쓰면 Claude가 기존 주제를 바탕으로 더 깊은 새 주제를 직접 정해 계속 쓴다(확장 모드).
요일별로 다룰 카테고리는 `curriculum.json` 의 `weekly_rotation`(월~금) 이 정한다.

### 주말 IT 트렌드

토·일에는 커리큘럼 대신 Hacker News, GeekNews, Reddit, GitHub Trending, 공식 블로그, 보안 매체 등을
교차 확인해 지난 7일간 가장 많이 이야기된 IT 이슈(AI, 언어/런타임, 보안, 클라우드, 오픈소스 등) 10개를 정리한다.
`Category = 📰 IT 트렌드`, `Level = 트렌드` 로 저장되며 진도·주간 요약 카운트에서는 빠진다.
일요일판은 토요일판과 겹치는 이슈를 빼고 후속 진전이나 새 이슈 위주로 채운다.

---

## 셋업 (1회)

### 1. Notion DB 만들기

Notion에서 새 데이터베이스(표)를 만들고 property를 **정확히 이 이름/타입으로** 맞춘다:

| 속성 | 타입 | 용도 |
|---|---|---|
| `Title` | 제목 | 주제명 |
| `Category` | 선택 | 카테고리 |
| `Level` | 선택 | 기초 / 응용 / 요약 / 트렌드 |
| `Date` | 날짜 | 생성일 (KST) |
| `Day` | 선택 | 월~일 |
| `Tags` | 다중 선택 | 키워드 |
| `Status` | 선택 | 미복습 / 복습완료 |

DB URL에서 32자 hex가 **DB ID**다:
`notion.so/workspace/`**`70d3b097f7a1430e87d5e96c2abc17d8`**`?v=...`

### 2. Notion Integration 연결

1. <https://www.notion.so/profile/integrations> 에서 Integration 생성 → 토큰(`ntn_...`) 복사
2. **DB 페이지 우상단 `⋯` > Connections > 방금 만든 integration 연결** ← 이거 빼먹으면 403

### 3. `.env` 작성

```bash
cp .env.example .env
# NOTION_TOKEN, NOTION_DB_ID 채우기
```

### 4. 스키마 점검 + Data Source ID 확보

```bash
bash scripts/verify-notion.sh
```

property 7개가 다 ✓ 로 나오고 `NOTION_DS_ID=...` 가 출력되면 그 값을 `.env` 에 채운다.

### 5. 로컬에서 첫 실행

```bash
claude /login          # Pro/Max 구독으로 로그인하면 구독 한도에서 차감
bash scripts/run-daily.sh
```

Notion DB에 오늘 자 페이지 2개가 생기면 성공. 실패하면 `logs/` 의 최신 로그부터 본다.

### 6. GitHub Actions 등록

레포 **Settings > Secrets and variables > Actions** 에 등록:

| Secret | 값 | 필수 |
|---|---|---|
| `NOTION_TOKEN` | `ntn_...` | ✅ |
| `NOTION_DB_ID` | 32자 hex | ✅ |
| `NOTION_DS_ID` | verify 스크립트가 알려준 값 | ✅ |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` 출력값 | 둘 중 하나 |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | 둘 중 하나 |

### 인증: 구독형 vs 종량과금

**Actions에서도 Pro/Max 구독을 쓸 수 있다.** 로컬에서 한 번 발급하면 된다:

```bash
claude setup-token     # 브라우저 OAuth → 장기 토큰 출력
```

출력된 토큰을 `CLAUDE_CODE_OAUTH_TOKEN` secret 에 넣으면 구독 한도에서 차감되고
API 크레딧 충전이 필요 없다. 종량과금 API 키를 쓰려면 `ANTHROPIC_API_KEY` 를 넣는다
(구독료와 **별개 지갑**이라 Console 에 크레딧을 충전해야 한다).

> **함정**: 인증 해석 순서가 `ANTHROPIC_API_KEY` → OAuth 다.
> 둘 다 등록하면 API 키가 먼저 잡혀서, 크레딧이 0 이면 구독 토큰이 있어도 실패한다.
> 워크플로가 이걸 막아주긴 하지만 (`CLAUDE_CODE_OAUTH_TOKEN` 이 있으면 API 키를 빈 값으로 덮는다),
> 로컬 `.env` 에서는 직접 한쪽을 비워둬야 한다.

**Notion DB가 진도의 단일 출처**라서 로컬/Actions 를 섞어 써도 중복이 안 생긴다.

등록 후 Actions 탭에서 `CS Daily` > `Run workflow` 로 수동 1회 실행해 검증한다.

---

## 운영 규칙 (프롬프트에 박아둔 것)

- **진도의 단일 출처는 Notion DB.** 로컬 progress 파일을 만들지 않으므로 어느 환경에서 돌려도 일관된다.
- **Catch-up 금지.** 어제 페이지가 없어도 어제 자를 만들지 않는다. 빠진 날은 의도된 일시정지.
- **중복 금지.** DB에 이미 있는 주제는 다시 안 뽑는다.
- **평일은 학습, 주말은 트렌드.** 커리큘럼을 완주하면 확장 모드로 계속 쓴다 (기한 없음).
- **잔디.** 성공한 날만 `til/` 에 기록을 커밋한다. 작성자를 본인 noreply 주소로 해야
  contribution 으로 집계된다 (워크플로의 `Commit study log` 스텝).
- **주간 요약**은 요일이 아니라 *마지막 요약 이후 누적 10주제 도달 시* 자동 생성된다.
- **KST 고정.** Actions 러너는 UTC라서, 스크립트가 KST 날짜를 계산해 프롬프트에 주입한다.

## 자주 만지게 될 것

- 주제를 바꾸고 싶다 → `curriculum.json` 배열 수정 (배열 순서 = 학습 순서)
- 페이지 본문 구성을 바꾸고 싶다 → `prompts/daily.md` 의 Step 5
- 주말 트렌드 출처·분야 비율을 바꾸고 싶다 → `prompts/weekend.md` 의 Step 3~4
- 요일별 카테고리를 바꾸고 싶다 → `curriculum.json` 의 `weekly_rotation`
- 실행 시각을 바꾸고 싶다 → `.github/workflows/daily.yml` 의 cron (UTC 기준으로 적어야 함)

## 수동 실행

```bash
bash scripts/run-daily.sh            # 요일에 맞게 자동 (til/ 파일은 생기지만 커밋은 직접)
bash scripts/run-daily.sh daily      # 요일 무관하게 CS 학습 페이지
bash scripts/run-daily.sh weekend    # 요일 무관하게 IT 트렌드 페이지
bash scripts/run-weekly.sh           # 주간 요약만
```
