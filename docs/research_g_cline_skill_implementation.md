# Cline 스킬 구현 방법 조사 결과

> 작성일: 2026-03-13
> 조사자: Research Agent

---

## 요약

Cline(VS Code AI 코딩 어시스턴트)에서 CadQuery 기반 대화형 기어 생성 워크플로우를 구현하는 데 활용할 수 있는 커스터마이징 메커니즘은 크게 4가지다: **Rules(.clinerules)**, **Skills**, **Workflows**, **Hooks**, 그리고 **MCP 서버 연동**. 이 중 CadQuery 연동에 가장 직접적이고 강력한 방법은 **MCP 서버 + Skills 조합**이며, 이미 `bertvanbrakel/mcp-cadquery`와 `rishigundakaram/cadquery-mcp-server`라는 검증된 오픈소스 CadQuery MCP 서버가 존재한다.

**핵심 결론:**
- Cline에는 "커스텀 모드(Custom Modes)"라는 별도 개념은 없다. Roo Code(Cline 포크)에는 존재하지만 Cline 자체에는 Plan/Act 두 가지 기본 모드만 있다.
- Cline의 커스터마이징은 Rules + Skills + Workflows + Hooks + MCP의 조합으로 구현한다.
- CadQuery MCP 서버는 stdio 방식으로 Cline과 즉시 연동 가능하며, Python 스크립트 실행 및 STEP/STL/SVG 파일 생성을 지원한다.

---

## Cline 커스터마이징 메커니즘 전체 맵

```
Cline 커스터마이징 레이어
│
├── 1. Rules (.clinerules)          ← AI에게 항상 적용되는 지침 (시스템 프롬프트에 주입)
│       └── 전역 규칙 + 프로젝트 규칙 + 조건부 규칙(파일 패턴)
│
├── 2. Skills                       ← 특정 작업에만 로드되는 모듈식 명령 세트
│       └── SKILL.md (YAML frontmatter + 마크다운 지침)
│
├── 3. Workflows                    ← /명령어로 실행하는 단계별 자동화 프로세스
│       └── .clinerules/workflows/*.md
│
├── 4. Hooks                        ← 워크플로우 이벤트에 주입되는 실행 스크립트
│       └── PreToolUse, PostToolUse, TaskStart 등 8가지 이벤트
│
└── 5. MCP Servers                  ← 외부 도구/Python 스크립트 실행 확장
        └── cline_mcp_settings.json에 등록
```

### Plan/Act 모드 (유일한 기본 내장 모드)

| 모드 | 권한 | 사용 시기 |
|------|------|-----------|
| Plan | 읽기 전용 (파일 탐색, 검색) | 설계 논의, 코드베이스 분석 |
| Act | 전체 (파일 쓰기, 명령 실행, 브라우저) | 실제 구현 |

두 모드에 각각 다른 AI 모델 할당 가능. 모드 전환은 UI 토글 또는 gRPC 요청으로 처리된다.

> 참고: Roo Code(Cline 포크)에는 JSON 기반 커스텀 모드(Architect, Code, Ask 등) 정의 기능이 있으나, 현재 Cline 공식 버전에는 해당 기능이 없다.

---

## Custom Modes 상세 가이드

### Cline에서의 "커스텀 모드" 대안

Cline 자체에는 Custom Modes UI가 없다. 대신 다음 방법으로 동등한 효과를 구현한다:

**방법 1: .clinerules 파일로 역할 정의**

```markdown
# .clinerules/gear-designer.md

## 역할
당신은 CadQuery 전문 기어 설계 어시스턴트입니다.

## 도메인 지식
- 인벌류트 기어의 기본 파라미터: 모듈(m), 잇수(z), 압력각(α=20°)
- 피치원 지름 = 모듈 × 잇수
- CadQuery로 기어 형상을 생성할 때 show_object(result) 필수

## 응답 규칙
- 기어 파라미터를 확인한 후 코드를 생성한다
- 생성된 .step 파일 경로를 항상 보고한다
- 수치 계산 근거를 설명한다
```

**방법 2: Skills로 도메인 전문 모드 구현**

Skills는 관련 요청이 들어올 때 자동으로 로드되므로, CadQuery 기어 생성용 Skill을 정의하면 사실상 "기어 설계 모드"로 동작한다.

---

## .clinerules 사용법 (예제 포함)

### 파일 위치

| 유형 | 위치 |
|------|------|
| 프로젝트 규칙 | `프로젝트루트/.clinerules/` |
| 전역 규칙 (macOS) | `~/Documents/Cline/Rules/` |
| 전역 규칙 (Windows) | `Documents\Cline\Rules\` |

워크스페이스 규칙이 전역 규칙보다 우선 적용된다.

### 지원 파일 형식

`.clinerules` 단일 파일 또는 `.clinerules/` 디렉토리 하위 `.md`/`.txt` 파일들

### 조건부 규칙 (YAML frontmatter)

특정 파일 패턴에만 활성화되는 규칙 정의:

```yaml
---
paths:
  - "**/*.py"
  - "gear_scripts/**"
---

# CadQuery Python 스크립트 규칙

- 모든 스크립트 끝에 show_object(result) 포함
- STEP 파일 출력 경로: output/ 디렉토리
- 파라미터는 함수 상단에 주석으로 명시
```

### CadQuery 프로젝트용 .clinerules 예제

```markdown
# .clinerules/01-cadquery-domain.md

## 도메인 컨텍스트
이 프로젝트는 CadQuery를 이용한 파라메트릭 기어 라이브러리입니다.

## 코딩 규칙
- CadQuery 버전: 2.4+
- Python 환경: conda env "cadquery"
- 모든 파라미터는 SI 단위 (mm, degree)

## 기어 설계 파라미터 체계
- module (m): 기어 모듈 (0.5 ~ 10)
- num_teeth (z): 잇수 (최소 8)
- pressure_angle: 압력각 (기본 20°)
- face_width: 치폭

## 파일 출력
- 생성된 모델은 output/ 폴더에 .step 형식으로 저장
- 명명 규칙: spur_gear_m{m}_z{z}.step
```

```markdown
# .clinerules/02-workflow.md

## 기어 생성 워크플로우
1. 사용자에게 파라미터 확인 (모듈, 잇수, 치폭)
2. 계산값 출력 (피치원 지름, 이끝원 지름, 이뿌리원 지름)
3. CadQuery 코드 생성
4. MCP 서버로 스크립트 실행
5. STEP 파일 경로 보고

## 오류 처리
- 기하 생성 실패 시 파라미터 재검토 제안
- 최소 잇수(8개) 미만 시 경고
```

### 규칙 토글 방법

Cline 채팅 입력창 아래 Rules 팝오버에서 각 파일을 활성화/비활성화. 활성화된 규칙의 내용이 시스템 프롬프트에 직접 추가된다.

---

## Skills 상세 가이드 (예제 코드 포함)

### Skills란

Skills는 특정 작업에 대한 Cline의 기능을 확장하는 모듈식 명령 세트다. Rules가 항상 활성화된 것과 달리, Skills는 관련 요청이 들어올 때만 로드되어 컨텍스트 토큰 소비를 최소화한다.

### 로딩 메커니즘

| 레벨 | 시점 | 토큰 비용 |
|------|------|----------|
| 메타데이터 (frontmatter) | 작업 시작 시 항상 | ~100 토큰/스킬 |
| 지침 (SKILL.md 본문) | 스킬 활성화 시 | 수백~수천 토큰 |
| 추가 리소스 (scripts/, docs/) | 필요 시 | 무제한 |

### 파일 구조

```
.cline/skills/
└── cadquery-gear-generator/
    ├── SKILL.md              # 필수: frontmatter + 지침
    ├── scripts/
    │   ├── generate_spur_gear.py
    │   └── calculate_params.py
    └── docs/
        └── gear_theory.md
```

### SKILL.md Frontmatter 형식

```yaml
---
name: cadquery-gear-generator
description: CadQuery로 파라메트릭 기어(스퍼, 헬리컬, 베벨)를 생성할 때 사용. 기어 모듈, 잇수, 치폭을 입력받아 STEP/STL 파일을 생성한다.
---
```

**핵심 필드:**
- `name`: 케밥케이스, 소문자, 최대 64자 (`^[a-z0-9-]+$` 패턴)
- `description`: 최대 1024자. "언제 이 스킬을 사용하는가"를 명확히 기술 (트리거 조건)

### 완성된 SKILL.md 예제

```markdown
---
name: cadquery-gear-generator
description: CadQuery로 파라메트릭 기어를 생성하거나, 기어 파라미터를 계산하거나, 기어 STEP/STL 파일을 내보낼 때 사용. 스퍼 기어, 헬리컬 기어, 베벨 기어를 지원한다.
---

# CadQuery 기어 생성 스킬

## 개요
이 스킬은 CadQuery Python 라이브러리를 사용하여 파라메트릭 기어 3D 모델을 생성한다.

## 전제 조건
- Python 환경에 cadquery, numpy 설치됨
- MCP 서버 `cadquery_stdio` 연결됨 (또는 직접 Python 실행)

## 파라미터 체계

| 파라미터 | 기호 | 단위 | 기본값 | 설명 |
|---------|------|------|--------|------|
| 모듈 | m | mm | 2 | 기어 크기 기준 단위 |
| 잇수 | z | - | 20 | 최소 8개 이상 권장 |
| 압력각 | α | ° | 20 | 표준 20° 또는 14.5° |
| 치폭 | b | mm | 10×m | 기어 두께 |

## 계산 공식

```
피치원 지름 (d) = m × z
이끝원 지름 (da) = m × (z + 2)
이뿌리원 지름 (df) = m × (z - 2.5)
기초원 지름 (db) = d × cos(α)
```

## 워크플로우

1. 사용자 파라미터 확인 (없으면 기본값 사용)
2. 계산값 표시
3. CadQuery 스크립트 생성
4. execute_cadquery_script 도구로 실행 (MCP 사용 시)
   또는 execute_command로 python 직접 실행
5. export_shape 도구로 STEP 파일 생성
6. 파일 경로와 SVG 미리보기 경로 보고

## 기어 유형별 접근법

### 스퍼 기어 (Spur Gear)
scripts/generate_spur_gear.py 스크립트 참조.
인벌류트 치형은 CadQuery의 spline으로 근사하거나
cq-gears 라이브러리(있는 경우) 활용.

### 헬리컬 기어
나선각(helix_angle) 추가 파라미터 필요.
twist 기능으로 extrude 시 비틀림 적용.

## 오류 처리
- 잇수 < 8: 언더컷 경고, 최소 8 권장
- 모듈 < 0.5 또는 > 10: 극단값 경고
- 스크립트 실행 실패: 오류 메시지 분석 후 수정 재시도
```

### Skills 저장 위치

| 유형 | 위치 |
|------|------|
| 프로젝트 전용 | `.cline/skills/` 또는 `.clinerules/skills/` |
| 전역 (macOS/Linux) | `~/.cline/skills/` 또는 `~/.agents/skills/` |
| 전역 (Windows) | `C:\Users\USERNAME\.cline\skills\` |

프로젝트 디렉토리가 전역보다 먼저 검색된다. 동일 이름 시 전역이 우선(추정).

---

## Workflows 사용법

### 정의

`/명령어`로 실행하는 단계별 자동화 마크다운 파일. 파일명이 곧 명령어가 된다.

### 저장 위치

| 유형 | 위치 |
|------|------|
| 프로젝트 | `.clinerules/workflows/` |
| 전역 (macOS/Linux) | `~/Documents/Cline/Workflows/` |
| 전역 (Windows) | `Documents\Cline\Workflows\` |

### CadQuery 기어 생성 Workflow 예제

```markdown
# create-gear.md  → /create-gear 로 실행

# 기어 생성 워크플로우

## Step 1: 파라미터 수집
<ask_followup_question>
  <question>기어 파라미터를 입력해주세요.</question>
  <options>["스퍼 기어 (기본값)", "직접 입력"]</options>
</ask_followup_question>

## Step 2: 계산 및 확인
파라미터를 기반으로 계산값(피치원 지름, 이끝원 지름 등)을 표시하고 사용자 확인을 받는다.

## Step 3: 스크립트 실행
<use_mcp_tool>
  <server_name>cadquery_stdio</server_name>
  <tool_name>execute_cadquery_script</tool_name>
  <arguments>{"script": "{{generated_script}}", "parameters": {}}</arguments>
</use_mcp_tool>

## Step 4: STEP 파일 내보내기
<use_mcp_tool>
  <server_name>cadquery_stdio</server_name>
  <tool_name>export_shape</tool_name>
  <arguments>{"format": "STEP", "output_path": "output/gear.step"}</arguments>
</use_mcp_tool>

## Step 5: 결과 보고
생성된 STEP 파일 경로와 기어 사양을 요약하여 보고한다.
```

---

## MCP 서버 연동 방법

### 등록 방법

Cline 패널 → MCP Servers 아이콘 → Configure 탭 → `cline_mcp_settings.json` 편집

또는 Cline에 GitHub URL을 제공하여 자동 설치 요청 가능.

### 설정 파일 형식 (stdio 방식 - Python 서버 권장)

```json
{
  "mcpServers": {
    "cadquery_stdio": {
      "command": "python",
      "args": ["/절대경로/server.py"],
      "env": {},
      "disabled": false
    }
  }
}
```

shell script 래퍼를 사용하는 경우:

```json
{
  "mcpServers": {
    "cadquery_stdio": {
      "command": "/절대경로/mcp-cadquery/server_stdio.sh",
      "args": ["--library-dir", "/절대경로/gear_library"],
      "alwaysAllow": [
        "execute_cadquery_script",
        "export_shape_to_svg",
        "export_shape",
        "scan_part_library",
        "search_parts"
      ]
    }
  }
}
```

### SSE 방식 (HTTP 원격 서버)

```json
{
  "mcpServers": {
    "cadquery_sse": {
      "url": "http://127.0.0.1:8000/mcp",
      "headers": {},
      "disabled": false
    }
  }
}
```

### Python MCP 서버 개발 기초 (FastMCP 사용)

```python
# server.py
from mcp.server.fastmcp import FastMCP
import cadquery as cq
import json

mcp = FastMCP("cadquery-gear-server")

@mcp.tool()
def generate_spur_gear(module: float, num_teeth: int, face_width: float) -> dict:
    """
    스퍼 기어를 생성하고 STEP 파일로 저장합니다.

    Args:
        module: 기어 모듈 (mm)
        num_teeth: 잇수
        face_width: 치폭 (mm)

    Returns:
        생성된 파일 경로와 기어 사양
    """
    pitch_diameter = module * num_teeth
    tip_diameter = module * (num_teeth + 2)

    # CadQuery로 간단한 기어 근사 생성
    gear = (cq.Workplane("XY")
            .circle(pitch_diameter / 2)
            .extrude(face_width))

    output_path = f"output/spur_m{module}_z{num_teeth}.step"
    cq.exporters.export(gear, output_path)

    return {
        "file_path": output_path,
        "pitch_diameter": pitch_diameter,
        "tip_diameter": tip_diameter,
        "face_width": face_width
    }

if __name__ == "__main__":
    mcp.run()
```

설치 및 등록:

```bash
pip install "mcp[cli]" cadquery
# 또는
uv add "mcp[cli]" cadquery
```

---

## 기존 CadQuery MCP 서버 분석

### 1. bertvanbrakel/mcp-cadquery

**GitHub:** https://github.com/bertvanbrakel/mcp-cadquery

**특징:**
- 임의의 CadQuery Python 스크립트 실행
- 파라미터 치환(Parameter substitution) 지원
- SVG 미리보기 생성 및 캐시
- 부품 라이브러리 스캔 및 검색 (docstring 메타데이터 기반)
- HTTP SSE 및 stdio 두 가지 모드 지원

**지원 도구:**

| 도구 | 기능 |
|------|------|
| `execute_cadquery_script` | CadQuery 스크립트 실행 + 파라미터 치환 |
| `export_shape_to_svg` | SVG 미리보기 생성 (캐시됨) |
| `export_shape` | STEP/STL 등 다양한 형식 내보내기 |
| `scan_part_library` | 부품 라이브러리 인덱싱 |
| `search_parts` | 인덱싱된 부품 검색 |

**Cline 연동 설정:**

```json
{
  "mcpServers": {
    "cadquery_stdio": {
      "command": "./server_stdio.sh",
      "args": ["--library-dir", "gear_library"],
      "alwaysAllow": ["execute_cadquery_script", "export_shape_to_svg",
                      "scan_part_library", "search_parts", "export_shape"]
    }
  }
}
```

**부품 라이브러리 메타데이터 형식:**

```python
"""
Name: Spur Gear M2 Z20
Description: Standard involute spur gear, module 2, 20 teeth
Tags: gear, spur, mechanical
Author: gear-lib
"""
import cadquery as cq
# ... 기어 코드 ...
```

### 2. rishigundakaram/cadquery-mcp-server

**GitHub:** https://github.com/rishigundakaram/cadquery-mcp-server

**특징:**
- Claude Code 전용으로 설계된 CAD 생성 및 검증 서버
- CAD 스크립트 유효성 검사 (기하학적 특성 확인)
- STEP/STL 형식 내보내기
- `uv sync --extra cad`로 설치

**지원 도구:**
- `verify_cad_query`: 스크립트가 정의된 기준을 충족하는지 검증 (PASS/FAIL)
- `generate_cad_query`: 자연어에서 스크립트 생성 (현재 미구현)

---

## Python 코드 실행 방법

### 방법 1: Cline의 execute_command (직접 실행)

Cline은 Act 모드에서 터미널 명령을 직접 실행할 수 있다. Python 파일 실행 예:

```bash
conda run -n cadquery python scripts/generate_gear.py --module 2 --teeth 20
```

- 사용자 승인 필요 (자동 승인 설정 가능)
- stdout/stderr 결과가 대화로 반환됨
- 생성된 파일(STEP, STL)은 파일시스템에 저장됨

### 방법 2: MCP 서버 통한 실행 (권장)

MCP 서버를 통해 Python CadQuery 코드 실행. 결과는 MCP 도구 응답으로 직접 반환된다.

장점:
- 사용자 승인 없이 실행 가능 (`alwaysAllow` 설정 시)
- 구조화된 응답 (파일 경로, 사양 등)
- 오류 처리가 명확함

### 방법 3: write_to_file + execute_command 조합

1. Cline이 Python 스크립트 파일을 작성 (`write_to_file`)
2. 터미널에서 실행 (`execute_command`)
3. 결과 파일 경로를 읽어 보고

### 실행 결과 확인 방법

생성된 STEP/STL 파일 확인:
- VS Code OCP CAD Viewer 확장: CadQuery/build123d 결과를 VS Code 내에서 직접 시각화
- STEP 파일을 Cline이 `read_file`로 읽어 구조 분석 (텍스트 형식)
- SVG 미리보기: `export_shape_to_svg` 도구 → VS Code 미리보기에서 확인

---

## CadQuery 연동을 위한 최적 접근법

### 권장 아키텍처

```
사용자 (자연어 요청)
    ↓
Cline (Rules + Skills로 도메인 컨텍스트 보유)
    ↓
.clinerules/gear-domain.md (기어 설계 도메인 지식 주입)
.cline/skills/cadquery-gear/SKILL.md (기어 생성 스킬 자동 로드)
    ↓
MCP 서버 (bertvanbrakel/mcp-cadquery, stdio 방식)
    ↓
CadQuery Python 라이브러리
    ↓
STEP/STL/SVG 파일 생성
    ↓
Cline이 파일 경로와 사양 보고
```

### 단계별 설정 가이드

**1단계: MCP 서버 설치**

```bash
git clone https://github.com/bertvanbrakel/mcp-cadquery
cd mcp-cadquery
# 첫 실행 시 자동으로 .venv-cadquery 환경 생성
./server_stdio.sh --help
```

**2단계: Cline에 MCP 서버 등록**

`cline_mcp_settings.json`에 추가:

```json
{
  "mcpServers": {
    "cadquery_stdio": {
      "command": "/절대경로/mcp-cadquery/server_stdio.sh",
      "args": ["--library-dir", "/절대경로/gear_library"],
      "alwaysAllow": [
        "execute_cadquery_script",
        "export_shape_to_svg",
        "export_shape",
        "scan_part_library",
        "search_parts"
      ]
    }
  }
}
```

**3단계: 프로젝트 Rules 설정**

```bash
mkdir -p .clinerules
# .clinerules/gear-domain.md 작성 (위 예제 참조)
```

**4단계: CadQuery 기어 Skill 생성**

```bash
mkdir -p .cline/skills/cadquery-gear-generator
# SKILL.md 작성 (위 예제 참조)
```

**5단계: 기어 생성 Workflow 작성 (선택)**

```bash
mkdir -p .clinerules/workflows
# .clinerules/workflows/create-gear.md 작성
# /create-gear 명령으로 실행 가능
```

---

## 구현 시나리오 제안

### 시나리오 A: 최소 구현 (빠른 시작)

**필요 구성요소:**
- `.clinerules/cadquery-rules.md` (기어 도메인 규칙)
- `cline_mcp_settings.json` (bertvanbrakel/mcp-cadquery 등록)

**동작 방식:**
사용자: "모듈 2, 잇수 20인 스퍼 기어 만들어줘"
→ Cline이 clinerules 기반으로 기어 코드 생성
→ execute_cadquery_script MCP 도구 호출
→ STEP 파일 저장, 경로 보고

**장점:** 설정 최소, 즉시 사용 가능
**단점:** 매번 도메인 지식을 시스템 프롬프트에 주입 (토큰 비용)

### 시나리오 B: Skills 기반 최적화 구현

**필요 구성요소:**
- `.cline/skills/cadquery-gear-generator/SKILL.md`
- `cline_mcp_settings.json` (MCP 서버 등록)
- `.clinerules/01-project-rules.md` (프로젝트 기본 규칙)

**동작 방식:**
기어 관련 요청이 감지될 때만 Skill 로드 → 토큰 효율적
기어 무관 작업에는 일반 Cline 동작

**장점:** 토큰 효율, 기어 도메인 외 작업 방해 없음
**단점:** Skill 트리거 조건 설명을 명확히 작성해야 함

### 시나리오 C: 완전 자동화 Workflow 구현

**필요 구성요소:**
- 시나리오 B의 모든 구성요소
- `.clinerules/workflows/create-gear.md`
- `.clinerules/workflows/batch-gear-set.md`
- `Hooks/TaskComplete` 스크립트 (결과 자동 로깅)

**동작 방식:**
`/create-gear` 명령 → 파라미터 수집 대화 → 계산 → 생성 → 보고까지 완전 자동화
`/batch-gear-set` → 기어 세트(드라이빙+드리븐) 한번에 생성

**장점:** 반복 작업 완전 자동화, 팀 공유 가능
**단점:** 초기 설정 시간 필요

### 시나리오 D: 커스텀 MCP 서버 직접 개발

**사용 시기:** 기존 MCP 서버가 요구사항을 충족하지 못할 때

```python
# gear_mcp_server.py
from mcp.server.fastmcp import FastMCP
import cadquery as cq
import numpy as np

mcp = FastMCP("gear-design-server")

@mcp.tool()
def generate_involute_gear(
    module: float,
    num_teeth: int,
    face_width: float,
    pressure_angle: float = 20.0,
    output_format: str = "STEP"
) -> dict:
    """정밀 인벌류트 기어 생성"""
    # 완전한 인벌류트 치형 계산 및 생성
    # ...
    pass

@mcp.tool()
def calculate_gear_mesh(
    gear1_teeth: int,
    gear2_teeth: int,
    module: float
) -> dict:
    """기어 페어 메시 계산"""
    # 중심거리, 속도비 등 계산
    pass
```

---

## 근거 출처 (URL 포함)

| 항목 | URL |
|------|-----|
| Cline 공식 문서 홈 | https://docs.cline.bot/ |
| .clinerules 공식 문서 | https://docs.cline.bot/customization/cline-rules |
| Skills 공식 문서 | https://docs.cline.bot/customization/skills |
| Workflows 공식 문서 | https://docs.cline.bot/customization/workflows |
| Hooks 공식 문서 | https://docs.cline.bot/customization/hooks |
| MCP 개요 | https://docs.cline.bot/mcp/mcp-overview |
| MCP 서버 추가/설정 | https://docs.cline.bot/mcp/adding-and-configuring-servers |
| MCP 서버 개발 프로토콜 | https://docs.cline.bot/mcp/mcp-server-development-protocol |
| Plan & Act 모드 (DeepWiki) | https://deepwiki.com/cline/cline/3.4-plan-and-act-modes |
| Skills 시스템 (DeepWiki) | https://deepwiki.com/cline/cline/7.4-skills-system |
| .clinerules 블로그 | https://cline.ghost.io/clinerules-version-controlled-shareable-and-ai-editable-instructions/ |
| bertvanbrakel/mcp-cadquery | https://github.com/bertvanbrakel/mcp-cadquery |
| rishigundakaram/cadquery-mcp-server | https://github.com/rishigundakaram/cadquery-mcp-server |
| SKILL.md 형식 사양 (DeepWiki) | https://deepwiki.com/biocontext-ai/skill-to-mcp/5.2-skill.md-format-specification |
| Cline Skills 사용기 (Medium) | https://medium.com/data-science-collective/using-skills-with-cline-3acf2e289a7c |
| Cline Hooks 소개 블로그 | https://cline.bot/blog/cline-v3-36-hooks |
