# CS Daily — Java/Backend Auto-learner

매일 새벽 5시 GitHub Actions가 Claude Code를 무인 실행해서 Notion DB에 페이지를 자동으로 작성.

- **평일(월~금)**: 자바/백엔드 CS 학습 페이지 2개 (`prompts/daily.md`)
- **주말(토·일)**: 지난 7일간 화제였던 IT 이슈 TOP 10 트렌드 페이지 1개 (`prompts/weekend.md`)

```
매일 05:00 KST
  → GitHub Actions cron
  → scripts/run-daily.sh  (요일 보고 평일=daily / 주말=weekend 자동 선택)
  → 평일: Notion DB를 스캔해 진도 판단 → 오늘 주제 2개 선정 → 페이지 생성
  → 주말: 웹 검색으로 지난 7일 IT 화제 수집 → 10개 선정 → 트렌드 페이지 생성
  → 성공하면 til/YYYY/YYYY-MM-DD.md 에 오늘 주제를 기록해 커밋·푸시
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

하루 2주제 × 평일 → **160주제 ≈ 16주** 
160주제를 다 쓰면 Claude가 기존 주제를 바탕으로 더 깊은 새 주제를 직접 정해 계속 쓴다(확장 모드).
요일별로 다룰 카테고리는 `curriculum.json` 의 `weekly_rotation`(월~금) 이 정한다.

### 주말 IT 트렌드

토·일에는 커리큘럼 대신 Hacker News, GeekNews, Reddit, GitHub Trending, 공식 블로그, 보안 매체 등을
교차 확인해 지난 7일간 가장 많이 이야기된 IT 이슈(AI, 언어/런타임, 보안, 클라우드, 오픈소스 등) 10개를 정리한다.
`Category = 📰 IT 트렌드`, `Level = 트렌드` 로 저장되며 진도·주간 요약 카운트에서는 빠진다.
일요일판은 토요일판과 겹치는 이슈를 빼고 후속 진전이나 새 이슈 위주로 채운다.

---

bash scripts/run-daily.sh weekend    # 요일 무관하게 IT 트렌드 페이지
bash scripts/run-weekly.sh           # 주간 요약만
```
