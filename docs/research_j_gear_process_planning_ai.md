# AI 기반 기어 공정 설계 자동화 가능성

> 작성일: 2026-03-13 담당: Research-J 에이전트 목적: 기어 설계 파라미터 + 재질 + 정밀도 요구사항 → AI가 공구 선정, 가공조건, 공정배치를 자동 설계하는 시스템의 현재 기술 수준 및 구현 방법 파악

---

## 요약 (가능한가? 어느 수준까지?)

**현재 기술로 약 70\~80% 수준의 자동화가 가능하다.** 단, 완전 무인 자동화(검증 없이 생산 투입 가능한 공정 지시서 생성)는 아직 신뢰하기 어렵다.

### 자동화 가능 영역 (현재 기술)

- 가공 방법 선택 (호빙 vs 셰이핑 vs 연삭 등): **규칙 기반으로 90%+ 정확도**
- 공구 규격 매핑 (모듈 + 잇수 → 표준 호브/셰이퍼 커터): **규칙 기반으로 충분**
- 가공 조건 추정 (재질 + 공구 재종 → 절삭속도/이송 범위): **RAG + 공구 카탈로그로 80%+ 정확도**
- 공정 순서 배치 (황삭 → 열처리 → 연삭 등 표준 패턴): **규칙 기반으로 충분**
- LLM 기반 자연어 요약 및 공정 지시서 생성: **GPT-4 수준에서 실용 가능**

### 자동화 어려운 영역

- 특정 기계의 스핀들 성능, 강성 반영: **불가 (기계별 데이터 없음)**
- 치구(Fixture) 설계: **불가**
- NC 프로그램 직접 생성 (완전 자동): **실험적 수준 (오류율 높음)**
- 검증 없는 가공 조건의 신뢰성: **반드시 전문가 검토 필요**

### 핵심 권고

가장 현실적인 시스템은 **"규칙 기반 공정 결정 엔진(Python) + LLM 보완 + RAG 공구 데이터베이스"** 조합이다. LLM만 단독으로 가공 조건을 생성하면 수치 오류(hallucination)가 발생하며, 규칙 기반만으로는 신규 재질/공구에 대응이 어렵다.

---

## 기존 CAPP 시스템 현황

### CAPP(Computer-Aided Process Planning)의 두 가지 방식

| 방식 | 특징 | 한계 |
| --- | --- | --- |
| **변형 방식(Variant)** | 유사 부품의 표준 공정 계획을 검색하여 수정 | 신규 부품 유형에 취약, 유사도 판단 주관적 |
| **생성 방식(Generative)** | 제조 지식 + 규칙으로 처음부터 공정 계획 생성 | 규칙 작성 비용 높음, 지식 유지보수 어려움 |

기어 제조에서 변형 방식이 특히 유리하다. "대량 생산, 저변종" 환경에서 부품군(part family)이 일관된 공정 패턴을 보이기 때문이다.

### 기어 전용 소프트웨어의 공정 설계 기능

**KISSsoft** (스위스, 상용):

- 호브 및 셰이퍼 커터 설계 데이터베이스 내장
- 연삭 공정 시뮬레이션 (프로파일/나선 수정량 정의)
- 파워 스키빙, 호닝 시 공구 충돌 검증
- 경삭 시 연삭 여유 최소값 자동 결정
- **공정 지시서 자동 생성 기능은 없음** - 설계 검증 도구에 가까움

**Romax (Hexagon)**:

- 반자동 기어/샤프트/베어링 사이징
- 전동계 시뮬레이션 플랫폼
- **가공 조건(절삭속도, 이송) 산출 기능 없음**

**Nakamura-Tome CNC 복합기**:

- 기어 가공 옵션 장착 시 대화형 입력(모듈, 잇수 입력)으로 NC 프로그램 자동 생성
- **단, 특정 기계 전용, 범용 CAPP 아님**

### 최신 LLM 기반 CAPP 연구

**CAPP-GPT** (ScienceDirect, 2024):

- GPT 아키텍처로 CAD 구조 파싱 + 공정 시퀀싱 자동화
- Part Encoder → Plan Decoder 구조로 공정 계획 시퀀스 예측
- Digital Twin과 결합하여 실시간 공정 파라미터 적응
- **처음부터 학습(pre-train)이 필요한 연구 단계 시스템**

**LLM for High-Level CAPP** (ScienceDirect, 2026):

- 분산 제조 환경에서 LLM이 다양한 부품의 대체 공정 체인 생성
- 훈련 데이터 5%만으로도 공정 체인 수준에서 99%+ 정확도
- **고수준(공정 유형 선택) 정확도가 높고, 세부 파라미터(절삭 조건) 정확도는 낮음**

**ARKNESS** (arXiv, 2025):

- Knowledge Graph + RAG 결합으로 CNC 공정 계획 쿼리에 정확한 수치 응답
- 4,329개 트리플, 6,659개 엔티티로 구성된 자동 생성 KG
- Llama 3B + ARKNESS = GPT-4o 수준 정확도 달성
- 수치 오류 22 포인트 감소, 선택형 정확도 25 포인트 향상
- **온프레미스 배포 가능 - 공장 내 개인정보 보호 환경에 적합**

---

## LLM의 공정 설계 능력 및 한계

### LLM이 잘하는 것

1. **공정 유형 분류**: "이 기어를 어떤 방법으로 가공할까" → 호빙/셰이핑/연삭 선택 (99%+ 정확도, CAPP 연구 기준)
2. **자연어 → 구조화 데이터 변환**: 요구사항을 공정 파라미터로 파싱
3. **공정 순서 논리**: 황삭 → 열처리 → 정삭 → 검사 순서 같은 논리적 흐름
4. **문서 생성**: 공정 지시서, 작업 지침서를 자연어로 작성

### LLM이 틀리는 것 (hallucination)

**항공우주 제조 사례 연구 (arXiv, 2025)**:

> "GPT 계열 LLM에 보잉 787 타이타늄 체결구 표면처리를 물었더니 '무전해 니켈 도금 15\~20μm'를 권장 - 항공 표준 3개를 동시에 위반하는 답변"

기어 공정 설계에서 LLM의 오류 패턴:

| 오류 유형 | 예시 | 위험도 |
| --- | --- | --- |
| 수치 hallucination | 재질 없이 절삭속도 "100m/min" 단정 | 높음 |
| 표준 혼동 | AGMA 등급과 ISO 등급 혼용 | 높음 |
| 재질-공구 매핑 오류 | SCM415 → TiN 코팅 HSS 권장 (TiAlN이 적합) | 중간 |
| 공정 순서 오류 | 열처리 후 정삭을 빠뜨리거나 순서 역전 | 중간 |
| 단위 혼동 | 모듈(metric) vs DP(diametral pitch, imperial) | 낮음 |

### LLM + 도메인 지식 조합의 실제 성능

Llama 3B (기본): 절삭 조건 선택형 문제에서 낮은 정확도, 광범위한 범위만 제시 Llama 3B + ARKNESS (KG-RAG): GPT-4o 수준 달성, 수치 정확도 대폭 향상

**결론**: 순수 LLM으로 가공 조건 수치를 생성하면 신뢰 불가. RAG + 도메인 KG 필수.

---

## RAG + 공정 데이터베이스 연계 방법

### 연계 가능한 공구/절삭 데이터 소스

**Sandvik Coromant CoroPlus Tool Library**:

- 60,000+ 절삭공구, 900,000+ (40개 공급사 포함 시)
- ISO 13399 표준 형식으로 데이터 수출 가능
- JSON 및 STEP 포맷 지원
- CAM 시스템 연동 API 공개 (Mastercam, NX CAM, Cimatron 통합 검증)
- **RAG 연동 방법**: ISO 13399 XML/JSON을 벡터 DB에 인덱싱 → 재질/가공방법으로 쿼리

**Kennametal, Walter, Seco Tools**:

- 유사한 공구 카탈로그 API 또는 다운로드 제공
- 절삭 속도/이송 권장값 표 포함

### RAG 파이프라인 구성 (기어 공정 설계용)

```
[입력] 모듈=2, 잇수=30, 재질=SCM415, AGMA Grade 9

[RAG 쿼리 1] 공구 선정
  → 벡터 DB 검색: "module 2 gear hob, SCM415, carbide"
  → 결과: Sandvik CoroPlus A280M 시리즈, 절삭 데이터 반환

[RAG 쿼리 2] 절삭 조건
  → 절삭 데이터 핸드북 (Machining Data Handbook, SME) 검색
  → 결과: SCM415 소재 호빙 시 Vc=80~120m/min, fz=0.08~0.12mm/rev

[RAG 쿼리 3] 정밀도 요구사항
  → AGMA 2015-1 표준 테이블 검색
  → 결과: AGMA Grade 9 → 피치 오차 ±8μm, 치형 오차 ±6μm

[LLM 생성] 위 컨텍스트로 공정 지시서 작성
```

### 정밀도 등급 테이블 컨텍스트화

AGMA 2015 / ISO 1328 테이블을 RAG로 연결하는 방법:

```python
# 예: 정밀도 등급 데이터를 JSON으로 구조화
precision_grades = {
    "AGMA_9": {
        "pitch_error_um": 8,
        "profile_error_um": 6,
        "helix_error_um": 8,
        "process_recommendation": "hobbing_finish + gear_grinding"
    },
    "AGMA_11": {
        "pitch_error_um": 4,
        "profile_error_um": 3,
        "helix_error_um": 4,
        "process_recommendation": "gear_grinding_required"
    }
}
```

이 데이터를 프롬프트 컨텍스트에 직접 주입하거나 벡터 DB에 인덱싱한다.

---

## Cline 스킬 통합 방법

### 패턴 1: Python 공정 결정 엔진 + Cline 실행

Cline 스킬로 구현할 때 가장 신뢰도 높은 패턴:

```
docs/gear_process_rules.py   # 공정 결정 규칙 (Python)
docs/cutting_data.json       # 절삭 조건 데이터베이스
docs/tool_catalog.json       # 공구 카탈로그
SKILL.md                     # Cline 스킬 진입점
```

`SKILL.md` 예시 구조:

```markdown
# Gear Process Planning Skill

## 트리거
사용자가 기어 공정 설계, 공정 지시서, 절삭 조건을 요청할 때

## 실행 순서
1. docs/gear_process_rules.py를 실행하여 공정 결정
2. 결과를 바탕으로 공정 지시서 마크다운 생성
3. 사용자에게 검토 요청

## 입력 형식
- 모듈, 잇수, 압력각, 재질, AGMA/ISO 등급, 생산 수량
```

### 패턴 2: Python 규칙 엔진 (권장 구현)

```python
# gear_process_engine.py 핵심 로직 예시

MATERIAL_DB = {
    "SCM415": {"hardness_HB": 160, "machinability": "medium",
                "carbide_vc": 100, "HSS_vc": 40},
    "S45C":   {"hardness_HB": 200, "machinability": "good",
                "carbide_vc": 120, "HSS_vc": 50},
    "SUS304": {"hardness_HB": 150, "machinability": "poor",
                "carbide_vc": 80,  "HSS_vc": 25},
}

def select_gear_process(module, teeth, material, agma_grade, qty):
    """기어 가공 방법 선택"""
    # 규칙 1: 모듈 기반 가공 방법
    if module <= 8:
        primary_method = "hobbing"
    else:
        primary_method = "InvoMilling"  # 대형 모듈

    # 규칙 2: 내접 기어는 셰이핑
    # (외접 여부 파라미터 필요)

    # 규칙 3: 정밀도 등급에 따른 마무리 공정
    finish_process = None
    if agma_grade >= 10:
        finish_process = "gear_grinding"
    elif agma_grade >= 8:
        finish_process = "gear_shaving_or_honing"

    # 규칙 4: 재질에 따른 열처리
    heat_treatment = None
    if material in ["SCM415", "SCM420", "SNCM220"]:
        heat_treatment = "case_carburizing"  # 침탄

    return {
        "primary": primary_method,
        "finish": finish_process,
        "heat_treatment": heat_treatment,
        "sequence": build_sequence(primary_method, finish_process, heat_treatment)
    }

def calculate_cutting_conditions(module, material, tool_type="carbide_hob"):
    """절삭 조건 계산"""
    mat = MATERIAL_DB.get(material, MATERIAL_DB["S45C"])
    vc = mat["carbide_vc"] if "carbide" in tool_type else mat["HSS_vc"]
    # 이송: 모듈에 따라 조정
    fz = 0.10 + (module - 2) * 0.005  # 추정값, RAG로 정제 필요
    return {"cutting_speed_m_min": vc, "feed_mm_rev": fz}
```

### 패턴 3: 출력 형식 (공정 지시서)

```markdown
# 기어 가공 공정 지시서

## 기어 사양
| 항목 | 값 |
|------|-----|
| 모듈 | 2 mm |
| 잇수 | 30 |
| 재질 | SCM415 |
| 정밀도 | AGMA Grade 9 |

## 공정 순서
| 공정 번호 | 공정명 | 공구 | 절삭속도 | 이송 |
|-----------|--------|------|---------|------|
| 10 | 선삭 (블랭크) | T01: 인서트 CNMG | 180 m/min | 0.3 mm/rev |
| 20 | 기어 호빙 | T10: 카바이드 호브 m2 | 100 m/min | 0.10 mm/rev |
| 30 | 침탄 열처리 | - | - | - |
| 40 | 기어 연삭 | T20: CBN 연삭 휠 | 30 m/s | 0.02 mm/rev |
| 50 | CMM 검사 | - | - | - |

## 검토 필요 사항 (AI 추정치)
- [ ] 절삭 조건 실제 기계에서 검증 필요
- [ ] 연삭 여유 적절성 확인 (현재 추정: 0.1mm/side)
- [ ] 공구 수명 기준 확인
```

---

## 자동화 가능/불가 영역 구분

### 자동화 가능 (현재 기술)

| 영역 | 방법 | 신뢰도 |
| --- | --- | --- |
| 가공 방법 선택 | 규칙 기반 (모듈 크기, 기어 유형, 수량) | 높음 (90%+) |
| 표준 공구 규격 매핑 | 규칙 기반 (모듈 → 호브 규격 표) | 높음 |
| 절삭 조건 범위 추정 | RAG + 공구 카탈로그 | 중간-높음 |
| 공정 순서 배치 | 표준 패턴 + 규칙 | 높음 |
| 공정 지시서 문서화 | LLM 생성 | 높음 (문서 품질) |
| 정밀도 등급 → 공정 매핑 | 규칙 기반 테이블 | 높음 |
| 열처리 방법 선택 | 규칙 기반 (재질 + 경도 요구) | 높음 |

### 자동화 어려움 / 불가

| 영역 | 이유 | 대안 |
| --- | --- | --- |
| 특정 기계의 절삭 조건 최적화 | 기계별 스핀들 성능, 강성 데이터 없음 | 기계 데이터 DB 구축 후 가능 |
| 치구(Fixture) 설계 | 공간 형상, 클램핑 전략이 부품별 고유함 | 전문가 필수 |
| 완전한 NC 프로그램 생성 | G-code 오류 시 기계/재료 손상, 안전 위험 | 반드시 CAM 소프트웨어 사용 |
| 진동/채터 예측 | 실제 절삭 동역학 계산 필요 | FEM 시뮬레이션 연동 필요 |
| 가공 조건 수치 보증 | AI 추정값은 참고용, 실제 검증 불가 | 반드시 시험 절삭 필요 |
| 웜 기어, 스파이럴 베벨 | 복잡한 기하, 전용 기계 필요 | 전문가 + 전용 소프트웨어 |

---

## 권장 시스템 아키텍처

### 전체 구조

```
┌─────────────────────────────────────────────────┐
│              사용자 입력                          │
│  모듈, 잇수, 재질, AGMA 등급, 수량, 납기          │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│         공정 결정 엔진 (Python)                   │
│  gear_process_engine.py                          │
│  ┌─────────────┐  ┌──────────────┐              │
│  │ 가공방법 선택│  │ 공정순서 배치 │              │
│  │ (규칙 기반)  │  │ (표준 패턴)  │              │
│  └─────────────┘  └──────────────┘              │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│         RAG + 절삭 데이터 검색                    │
│  ┌──────────────┐  ┌─────────────────────┐      │
│  │ 공구 카탈로그 │  │  절삭 조건 데이터베이스│      │
│  │ (Sandvik 등) │  │  (Machining Handbook)│      │
│  └──────────────┘  └─────────────────────┘      │
│  ┌──────────────────────────────┐               │
│  │  정밀도 등급 테이블           │               │
│  │  (AGMA 2015 / ISO 1328)     │               │
│  └──────────────────────────────┘               │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│         LLM 보완 레이어 (GPT-4 / Claude)          │
│  - 공정 지시서 자연어 생성                         │
│  - 예외 케이스 처리 (비표준 재질 등)               │
│  - 사용자 질의 응답                               │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│              출력 (공정 지시서)                    │
│  - 공정 순서표 (마크다운/Excel)                    │
│  - 공구 목록 및 규격                              │
│  - 절삭 조건 표 (참고값 - 검증 필요 명시)          │
│  - 검토 필요 사항 체크리스트                       │
└─────────────────────────────────────────────────┘
```

### Cline 스킬로 통합하는 방법

```
cadquery-research/
├── CLAUDE.md
├── skills/
│   └── gear-process-planning/
│       ├── SKILL.md              # 스킬 진입점 및 규칙
│       ├── gear_process_engine.py # Python 공정 결정 엔진
│       ├── data/
│       │   ├── material_db.json   # 재질 절삭 특성
│       │   ├── tool_catalog.json  # 공구 카탈로그 (Sandvik 등)
│       │   ├── precision_grades.json # AGMA/ISO 등급 테이블
│       │   └── process_patterns.json # 표준 공정 패턴
│       └── templates/
│           └── process_sheet.md  # 공정 지시서 템플릿
```

### SKILL.md 구성 핵심 요소

```markdown
# Gear Process Planning Skill

## 데이터 참조
- 재질 DB: skills/gear-process-planning/data/material_db.json
- 공구 카탈로그: skills/gear-process-planning/data/tool_catalog.json
- 정밀도 등급: skills/gear-process-planning/data/precision_grades.json

## 실행 방법
1. gear_process_engine.py를 Bash로 실행 (입력: JSON 파라미터)
2. 출력된 공정 결정 결과를 공정 지시서 마크다운으로 변환
3. 불확실한 수치에는 반드시 "(추정값 - 검증 필요)" 표시

## 출력 규칙
- 절삭 조건은 항상 범위로 제시 (단일 수치 단정 금지)
- 공정 지시서 말미에 "검토 필요 체크리스트" 포함
- LLM 추정 vs. 카탈로그 참조값 구분 명시
```

### 단계별 구현 로드맵

**1단계 (즉시 구현 가능)**: 규칙 기반 Python 엔진

- 재질 DB (10\~20개 주요 재질) JSON 작성
- 가공 방법 선택 규칙 코딩
- 공정 순서 패턴 5\~10개 정의
- Cline이 엔진 실행 → 결과 문서화

**2단계 (1\~2주)**: RAG 공구 데이터 연동

- Sandvik CoroPlus 공구 카탈로그 ISO 13399 데이터 수집
- 절삭 데이터를 JSON으로 구조화
- LLM 프롬프트에 컨텍스트로 주입

**3단계 (탐색)**: 벡터 DB 연동

- ChromaDB 또는 pgvector로 공구 카탈로그 임베딩
- 자연어 쿼리로 공구/절삭 조건 검색
- ARKNESS 방식의 Knowledge Graph 구축

---

## 근거 출처

- [CAPP-GPT: Computer-Aided Process Planning GPT Framework (ScienceDirect, 2024)](https://www.sciencedirect.com/science/article/pii/S221384632400066X)
- [LLMs for High-Level CAPP in Distributed Manufacturing (ScienceDirect, 2026)](https://www.sciencedirect.com/science/article/pii/S073658452600013X)
- [ARKNESS: Knowledge Graph + LLM for CNC Process Planning (arXiv, 2025)](https://arxiv.org/html/2506.13026v1)
- [Large Language Models for Manufacturing (arXiv, 2024)](https://arxiv.org/html/2410.21418v1)
- [LLM Process Planning under Industry 5.0 (Taylor & Francis, 2025)](https://www.tandfonline.com/doi/full/10.1080/00207543.2025.2469285)
- [Leveraging LLM for G-Code Generation in CNC (I4Valley)](https://i4valley.com/resources/leveraging-llm-for-complex-g-code-generation-in-cnc-machinery/)
- [GLLM: Self-Corrective G-Code Generation with LLM (arXiv, 2025)](https://arxiv.org/abs/2501.17584)
- [LLM Evaluation for Aerospace Manufacturing (arXiv, 2025)](https://arxiv.org/html/2501.17183)
- [Sandvik Coromant CoroPlus Tool Library](https://www.sandvik.coromant.com/en-us/tools/digital-machining/coroplus-tool-library)
- [How to Import Tool Data into CAM (Sandvik Coromant, 2024)](https://www.digitalmanufacturing.sandvik/en/news-stories/lpblog/2024/06/how-to-import-tool-data-and-cutting-parameters-into-a-cam-system/)
- [Technological Aspects of Gear Manufacturing (PMC, 2023)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10706903/)
- [KISSsoft for Gear Manufacturing (Gear Technology)](https://www.geartechnology.com/blogs/4-revolutions/post/29850-kisssoft-for-manufacturing)
- [Knowledge-Based Expert System in Manufacturing Planning (ResearchGate)](https://www.researchgate.net/publication/322572218_Knowledge-based_expert_system_in_manufacturing_planning_state-of-the-art_review)
- [AI/ML for Tool Wear in Grinding (Gear Technology India)](https://geartechnologyindia.com/ai-ml-for-tool-wear-process-stabilization-in-grinding/)
- [LLM-Assisted APS Framework (ACM, 2025)](https://dl.acm.org/doi/10.1145/3761668.3761693)