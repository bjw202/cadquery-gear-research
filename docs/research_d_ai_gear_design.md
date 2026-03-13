# AI 보조 기어 설계 가능성 조사 (Research-D)

> 작성일: 2026-03-13
> 담당: Research-D 에이전트
> 목적: "기어 파라미터를 AI에게 자연어로 주면 3D 기어가 생성된다"는 워크플로우의 실현 가능성과 한계 파악

---

## 요약

현재 기술 수준에서 AI 보조 기어 설계 자동화는 **부분적으로 실현 가능**하다. 단, 완전 자동화(자연어 입력 → 검증된 기어 STEP 파일 출력)는 아직 인간 검증 단계 없이는 신뢰하기 어렵다.

- **가장 현실적인 시나리오**: 사용자가 파라미터(모듈, 잇수, 압력각 등)를 구조화된 형태로 입력 → AI가 `cq_gears` 라이브러리 호출 코드를 생성 → 자동 실행 → STEP 파일 출력. 이 경우 인볼류트 수식 오류 위험은 라이브러리가 흡수하므로 높은 신뢰도 가능.
- **가장 위험한 시나리오**: LLM이 인볼류트 치형 수식을 처음부터 직접 구현 → 수식 오류, 언더컷 미처리, 물림률 계산 누락 등 기하 오류가 숨어 있을 가능성이 높음. 반드시 인간 검증 필요.

---

## CadQuery MCP Server 현황

### 존재하는 MCP Server

| 프로젝트 | GitHub | 상태 | 특징 |
|----------|--------|------|------|
| cadquery-mcp-server | [rishigundakaram/cadquery-mcp-server](https://github.com/rishigundakaram/cadquery-mcp-server) | 부분 구현 | `verify_cad_query` 동작, `generate_cad_query`는 stub(미구현) |
| cad-query-workspace | [rishigundakaram/cad-query-workspace](https://github.com/rishigundakaram/cad-query-workspace) | 동작 | Claude에게 CadQuery 문서 + 예제 제공. `generate_cad_query`, `verify_cad_query` 노출 |
| CQAsk | [OpenOrion/CQAsk](https://github.com/OpenOrion/CQAsk) | 동작 | 웹 UI + OpenAI API 키로 자연어 → CadQuery 코드 생성 |

### Claude가 CadQuery를 직접 실행하는 워크플로우

`cad-query-workspace` MCP 기준 실제 워크플로우:

1. Claude가 사용자 자연어 요청을 수신
2. MCP의 `docs/cadquery/` 문서와 `examples/` 스크립트를 참조하여 CadQuery Python 코드 작성
3. `generate_cad_query` 툴로 코드 실행 → `outputs/` 디렉토리에 STL/STEP 파일 저장
4. `verify_cad_query` 툴로 치수·구조 검증 (pass/fail + 세부 결과 반환)
5. 오류 시 Claude가 에러 메시지를 받아 코드 수정 후 재실행 (자동 피드백 루프)

실제 사례: 2026년 3월 Medium 기사("I Taught Claude to Design 3D-Printable Parts")에서 Claude가 CadQuery 스크립트를 작성하고, trimesh+pyrender로 4방향 프리뷰 이미지를 렌더링하여 사용자에게 시각적 피드백을 제공하는 워크플로우 확인.

### 설치 방법 (cad-query-workspace 기준)

`~/.claude/claude_desktop_config.json` (또는 Claude Code MCP 설정)에 아래 추가:

```json
{
  "mcpServers": {
    "cadquery": {
      "command": "python",
      "args": ["/path/to/cad-query-workspace/server.py"]
    }
  }
}
```

---

## LLM + 기어 설계 가능성 분석

### LLM이 기어 파라미터로 CadQuery 코드를 생성할 수 있는가

**결론: 가능하나, 방법에 따라 신뢰도가 크게 달라진다.**

두 가지 접근 방식의 신뢰도 차이:

| 접근 방식 | 설명 | 신뢰도 | 권장 여부 |
|-----------|------|--------|-----------|
| A. 라이브러리 활용 | LLM이 `cq_gears` 라이브러리 파라미터만 채워 호출 | 높음 | **권장** |
| B. 수식 직접 구현 | LLM이 인볼류트 곡선, 치형 프로파일을 처음부터 코드로 구현 | 낮음 | 비권장 |

**cq_gears 라이브러리**: [meadiode/cq_gears](https://github.com/meadiode/cq_gears)는 CadQuery 기반 인볼류트 기어 파라메트릭 모델링 전용 라이브러리. 스퍼 기어, 헬리컬 기어, 헤링본 기어, 링 기어, 유성 기어셋, 베벨 기어, 기어 랙을 지원.

LLM이 생성해야 하는 코드의 최소 형태:

```python
from cq_gears import SpurGear
import cadquery as cq

gear = SpurGear(module=2.0, teeth_number=20, width=10.0, bore_d=8.0)
result = cq.Workplane("XY").gear(gear)
cq.exporters.export(result, "gear.step")
```

이 수준의 코드 생성은 LLM에게 매우 쉬운 작업이며, 정확도는 거의 100%에 가깝다.

### 인볼류트 치형 수식의 정확도

LLM이 인볼류트 수식을 **처음부터 직접 구현**할 경우의 위험 요소:

- 인볼류트 함수 정의 오류: `inv(α) = tan(α) - α` 구현 실수
- 기저원(base circle), 피치원(pitch circle), 이끝원(addendum circle) 반경 계산 혼용
- 20° 표준 압력각과 실제 작동 압력각(operating pressure angle)의 혼동
- 치형 간섭(undercut) 조건 미처리 — 잇수 17 미만 시 발생, 무시하면 조립 후 잼(jam) 현상
- 프로파일 시프트(profile shift) 계산 누락
- 물림률(contact ratio) 검증 미시행

실제 연구 결과: Text-to-CadQuery 논문(2505.06507)에서 "복잡한 수학 계산이 필요한 부품(인볼류트 기어 등)에서 LLM의 성능이 저하됨"을 확인. 스프링·기어가 플랜지·너트·샤프트보다 실행 시간과 오류율이 높다고 보고.

### 자동 피드백 루프 가능성

**가능하며, 효과가 입증되어 있다.**

- 피드백 루프 없이: CadQuery 코드 실행 성공률 약 53%
- 피드백 루프 적용 후 (실행 → 오류 메시지 → LLM 수정 → 재실행): 성공률 약 85%

단, CadQuery의 에러 메시지는 raw Python 예외(구조화되지 않은 stack trace)이므로 LLM이 근본 원인을 파악하기 어려운 경우가 있다. 메서드 체이닝 구조상 오류 발생 위치와 실제 원인이 다른 줄에 있는 경우가 많다.

---

## 실현 가능한 워크플로우 시나리오

### 시나리오 A: 자연어 입력 → AI 코드 생성 → 자동 실행 → STEP 출력

```
사용자: "모듈 2, 잇수 20, 압력각 20도, 폭 10mm 스퍼 기어 만들어줘"
   ↓
Claude (MCP 활용):
  1. cq_gears 라이브러리 파라미터로 매핑
  2. CadQuery 코드 생성
  3. verify_cad_query로 실행 검증
  4. STEP 파일 출력
   ↓
결과: gear.step 파일 (STEP CAD 포맷)
```

**평가**: 현재 기술 수준에서 **실현 가능**. cq_gears 라이브러리가 수식 복잡도를 흡수하므로 LLM 오류 위험이 낮음. 단, `generate_cad_query` 툴이 완전 구현된 MCP 서버가 필요함 (현재 공개 서버는 일부 미구현 상태).

**성공 조건**: cq_gears 설치, MCP 서버 동작, 기어 유형이 라이브러리 지원 범위 내
**실패 조건**: 기어 유형이 라이브러리 미지원(예: 웜 기어), 설치 환경 문제

### 시나리오 B: 파라미터 입력 → AI 검증 + 코드 생성 → 실행

```
사용자: 모듈=2, 잇수=12, 압력각=20°, 폭=8mm, 보어=6mm 입력
   ↓
AI 검증:
  - 잇수 12 < 17: 언더컷 경고 발생 → 프로파일 시프트 권고
  - 물림률 계산: 접촉비 확인
   ↓
CadQuery 코드 생성 + 실행 → STEP 출력
```

**평가**: 현재 기술 수준에서 **가장 신뢰도 높은 시나리오**. AI가 수식 생성보다 검증(validation) 역할을 맡을 때 오류 위험이 낮음. 잇수 < 17 같은 언더컷 조건은 LLM이 텍스트로 알고 있지만, 실제 보정 수식 적용은 라이브러리에 위임하는 것이 안전.

**시나리오 비교 결론**: **시나리오 B가 더 실현 가능하며 안전**. 시나리오 A는 편의성이 높지만 자연어의 모호성(예: "중간 크기 기어")을 파라미터로 변환하는 단계에서 오류 가능성이 있음.

---

## AI의 한계 및 사람이 검증해야 할 부분

### LLM이 기어 설계에서 틀리기 쉬운 부분

| 항목 | 위험도 | 설명 |
|------|--------|------|
| 인볼류트 곡선 수식 | **높음** | `inv(α) = tan(α) - α` 구현 및 이산 포인트 계산 오류 빈번 |
| 언더컷 조건 판단 | **높음** | 잇수 < 17(20° 기준) 언더컷 자동 감지 및 프로파일 시프트 적용 누락 |
| 물림률(contact ratio) 계산 | **중간** | 1.2 이상 유지 조건 검증 누락 시 소음/진동 발생 |
| 기어 쌍 중심거리 계산 | **중간** | 헬리컬 기어, 프로파일 시프트 적용 시 중심거리가 단순 공식과 달라짐 |
| Wire/Edge 타입 혼용 | **중간** | CadQuery API에서 Wire와 Edge는 다른 추상화 레벨 — LLM이 혼동하여 실행 오류 발생 |
| 단위 일관성 | **낮음** | mm/inch 혼용, 모듈(metric) vs DP(imperial) 혼동 |

### 자동화가 어려운 부분

1. **기어 강도 검증**: 루이스 굽힘 응력(Lewis bending stress), 헤르츠 접촉 응력 계산은 LLM이 수식은 알지만 재료 데이터(허용 응력값)와 결합하면 오류 가능성이 높음
2. **기어 쌍 조립 시뮬레이션**: 두 기어가 실제로 잘 물리는지(mesh interference 없는지) 3D 충돌 감지가 필요 — CadQuery의 `verify_cad_query`만으로는 불충분
3. **복잡한 기어 유형**: 웜 기어, 스파이럴 베벨 기어 — cq_gears도 미지원, LLM도 수식 오류 위험 높음
4. **제조 공차 적용**: 기어 등급(AGMA, ISO)에 따른 공차 적용은 기계 설계 전문 지식 필요

### 사람이 반드시 검증해야 하는 부분

- **언더컷 발생 여부**: 잇수 < 17(20° 압력각 기준)인 경우
- **물림률 확인**: 1.2 이상인지 (이하 시 소음, 진동, 수명 저하)
- **STEP 파일 치수 검증**: 실제 모듈값과 내보낸 파일 치수 일치 여부
- **강도 계산 (하중이 있는 경우)**: AI 생성 코드에는 강도 검증이 포함되지 않음
- **기어 쌍 간섭 확인**: 두 기어 조립 후 실제 메시(mesh) 간섭이 없는지

---

## 현재 존재하는 도구 및 프로젝트

### AI + CadQuery 연동 기존 프로젝트

| 프로젝트 | 유형 | 상태 | 기어 특화 |
|----------|------|------|-----------|
| [cadquery-mcp-server](https://github.com/rishigundakaram/cadquery-mcp-server) | MCP Server | 부분 구현 | 아니오 |
| [cad-query-workspace](https://github.com/rishigundakaram/cad-query-workspace) | MCP Workspace | 동작 | 아니오 |
| [CQAsk](https://github.com/OpenOrion/CQAsk) | 웹 앱 (OpenAI 기반) | 동작 | 아니오 |
| Text-to-CadQuery (논문) | 파인튜닝 모델 (Qwen2.5-3B) | 연구 단계 | 아니오 |
| CAD-Coder (논문) | VLM 파인튜닝 | 연구 단계 | 아니오 |

### 기어 특화 CadQuery 라이브러리

| 프로젝트 | 지원 기어 종류 | AI 연계 여부 |
|----------|--------------|-------------|
| [cq_gears](https://github.com/meadiode/cq_gears) | 스퍼, 헬리컬, 헤링본, 링, 유성, 베벨, 랙 | 아니오 (단독 라이브러리) |
| [cadquery-contrib/Involute_Gear.py](https://github.com/CadQuery/cadquery-contrib/blob/master/examples/Involute_Gear.py) | 스퍼 기어 (예제) | 아니오 |

**핵심 발견**: 기어 특화 AI 설계 도구는 아직 존재하지 않는다. 현재의 접근은 범용 LLM + 기어 라이브러리의 조합이다.

---

## 권고 사항

### 단기 권고 (즉시 실행 가능)

1. **cq_gears 라이브러리 채택**: 인볼류트 수식 오류 위험을 제거하는 가장 확실한 방법. 수동 계산 없이 파라미터만 입력.

2. **MCP + cq_gears 조합 워크플로우 구성**:
   - cad-query-workspace MCP 서버를 기반으로
   - `cq_gears` 사용 예제를 MCP의 `examples/` 폴더에 추가
   - Claude가 파라미터를 파싱하여 cq_gears 코드 생성 → 실행 → STEP 반환

3. **AI 역할 분리**: AI는 수식 구현자가 아닌 파라미터 파서 + 코드 조립자로 사용. 수식은 검증된 라이브러리가 담당.

### 중기 권고 (1~2주 내)

4. **언더컷 자동 경고 프롬프트 작성**: 잇수 < 17 입력 시 AI가 자동으로 언더컷 경고 + 프로파일 시프트 옵션 제시하도록 시스템 프롬프트 구성.

5. **검증 체크리스트 자동화**: 모듈, 잇수, 물림률, 중심거리를 AI가 출력과 함께 리포트하도록 파이프라인 구성.

### 장기 권고 (탐색 단계)

6. **빌드123d 전환 검토**: 기어 라이브러리 생태계가 성숙하면 build123d 기반으로 전환. 현재는 cq_gears가 CadQuery 전용이므로 CadQuery 유지가 합리적.

---

## 근거 출처

- [Text-to-CadQuery: A New Paradigm for CAD Generation (arXiv:2505.06507)](https://arxiv.org/html/2505.06507v1) — 성공률 69.3%, 피드백 루프 효과, 복잡 부품 한계
- [CAD-Coder: Open-Source Vision-Language Model for CAD Code (arXiv:2505.14646)](https://arxiv.org/html/2505.14646) — LLM 기본 지식 부재, 파인튜닝 필요, 기어 미지원
- [cq_gears GitHub (meadiode)](https://github.com/meadiode/cq_gears) — 기어 파라메트릭 라이브러리 지원 범위
- [cadquery-mcp-server GitHub (rishigundakaram)](https://github.com/rishigundakaram/cadquery-mcp-server) — MCP 서버 구현 상태
- [cad-query-workspace GitHub (rishigundakaram)](https://github.com/rishigundakaram/cad-query-workspace) — Claude 연동 워크스페이스
- [CQAsk GitHub (OpenOrion)](https://github.com/OpenOrion/CQAsk) — 오픈소스 LLM CAD 생성 도구
- [SplineCloud Blog: Parametric Gear Models with CadQuery](https://splinecloud.com/blog/creating-parametric-gear-models-with-streamlit-and-cadquery/) — 인볼류트 수식 및 파라미터 구조
- [LLM4CAD: Multi-Modal Large Language Models for CadQuery](https://sidilab.net/wp-content/uploads/2025/01/llm4cad_jcise_preprint.pdf) — 기어/스프링 생성 어려움, 피드백 루프 53→85% 성공률
- [Snyk: 9 MCP Servers for CAD with AI](https://snyk.io/articles/9-mcp-servers-for-computer-aided-drafting-cad-with-ai/) — CAD MCP 서버 생태계 현황
- [I Taught Claude to Design 3D-Printable Parts (Medium, 2026-03)](https://medium.com/@nchourrout/i-taught-claude-to-design-3d-printable-parts-heres-how-675f644af78a) — 실제 Claude+CadQuery 워크플로우 사례
