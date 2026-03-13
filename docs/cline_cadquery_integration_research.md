# Cline + CadQuery 기어 생성 시스템 구현 방법

> 작성일: 2026-03-13
> 조사 목적: "Cline에게 기어 파라미터를 말하면 → CadQuery 코드 생성 → 실행 → STEP/STL 출력"이 되는 구체적인 구현 방법 파악

---

## 요약

Cline은 VS Code 내에서 Python 스크립트를 터미널로 직접 실행할 수 있으며, MCP(Model Context Protocol) 서버와 통합도 지원한다. 기어 생성 시스템 구축에는 세 가지 시나리오가 실용적이며, 즉시 적용 가능한 MCP 서버(`bertvanbrakel/mcp-cadquery`)가 이미 존재한다. 권장 아키텍처는 **시나리오 A + C 복합** 방식(`.clinerules`에 기어 도메인 지식 주입 + 기어 라이브러리 + 터미널 직접 실행)으로, 외부 MCP 서버 의존성 없이 즉시 구동 가능하다.

---

## 1. Cline의 Python 실행 능력

### 1.1 터미널 직접 실행

VSCode v1.93의 shell integration 업데이트 이후 Cline은 터미널 명령을 직접 실행하고 출력을 수신할 수 있다.

- `python gear_generator.py` 형태의 스크립트 직접 실행 가능
- 실행 결과(표준 출력/오류)를 Cline이 읽고 후속 처리 가능
- 파일 생성 확인(`ls outputs/` 등)으로 STEP/STL 출력 검증 가능

### 1.2 Auto-Approve 설정

| 레벨 | 동작 |
|------|------|
| 기본 | 모든 터미널 명령에 사용자 승인 요청 |
| Execute safe commands | `ls`, `cat` 등 안전한 명령 자동 승인 |
| Execute all commands | 모든 명령 자동 승인 |
| YOLO Mode | 파일 변경, 터미널, MCP 도구 전부 자동 승인 |

### 1.3 오류 발생 시 자동 수정 루프

Cline은 터미널 출력에서 오류를 감지하면 자동으로 코드를 수정하고 재실행하는 루프를 형성한다. `.clinerules`에 "CadQuery 오류 발생 시 파라미터 범위 검증 후 재시도" 규칙을 명시하면 더 정확한 수정이 가능하다.

---

## 2. 구현 시나리오 비교 (A/B/C)

### 시나리오 A: .clinerules + Python 직접 실행

**구현 방식**
```
사용자: "모듈 2, 치수 20개, 헬리컬 기어 만들어줘"
  → Cline이 .clinerules 참조하여 CadQuery 코드 생성
  → python gear_generator.py 터미널 실행
  → outputs/gear_m2_z20.step 생성 확인
```

**파일 구조**
```
project/
├── .clinerules/
│   ├── 01-gear-domain.md       # 기어 설계 도메인 지식
│   ├── 02-cadquery-patterns.md # CadQuery 코드 패턴
│   └── workflows/
│       └── generate-gear.md    # 기어 생성 워크플로우
├── gear_library/
│   ├── __init__.py
│   ├── spur_gear.py
│   ├── helical_gear.py
│   └── bevel_gear.py
├── gear_generator.py           # CLI 진입점
└── outputs/                    # STEP/STL 출력
```

**장점**
- 외부 서버 의존성 없음 (즉시 시작 가능)
- 기어 라이브러리를 완전히 제어 가능
- Cline이 코드를 직접 수정·개선 가능
- 디버깅이 직관적

**단점**
- Cline이 매 요청마다 코드 생성 → 일관성 편차 발생 가능
- 복잡한 기어 파라미터 검증을 코드에 직접 구현해야 함

---

### 시나리오 B: MCP 서버 방식

**사용 가능한 MCP 서버 비교**

| 서버 | 제공 도구 | 성숙도 | Cline 연동 |
|------|-----------|--------|------------|
| `bertvanbrakel/mcp-cadquery` | execute_cadquery_script, export_shape, scan_part_library, search_parts, export_shape_to_svg | 높음 (5개 도구, 파트 라이브러리 지원) | stdio/SSE 모두 지원 |
| `rishigundakaram/cadquery-mcp-server` | verify_cad_query, generate_cad_query(stub) | 낮음 (generate는 미구현) | Claude Desktop 위주 |

**bertvanbrakel/mcp-cadquery 설치 및 설정**

```bash
# 설치
git clone https://github.com/bertvanbrakel/mcp-cadquery
cd mcp-cadquery
./server_stdio.sh  # 첫 실행 시 .venv-cadquery 자동 생성

# Cline cline_mcp_settings.json에 추가
{
  "mcpServers": {
    "cadquery": {
      "command": "/path/to/mcp-cadquery/server_stdio.sh",
      "args": ["--library-dir", "/path/to/gear_library"],
      "alwaysAllow": [
        "execute_cadquery_script",
        "export_shape",
        "export_shape_to_svg",
        "scan_part_library",
        "search_parts"
      ]
    }
  }
}
```

**MCP 도구 호출 예시**

```json
// execute_cadquery_script 호출
{
  "script": "import cadquery as cq\nfrom cq_gears import SpurGear\ngear = SpurGear(module=2.0, teeth_number=20, width=15.0, bore_d=10.0)\nresult = cq.Workplane('XY').gear(gear)",
  "parameters": {"module": 2.0, "teeth": 20}
}

// export_shape 호출 (STEP 출력)
{
  "shape_name": "result",
  "format": "STEP",
  "output_path": "outputs/gear.step"
}
```

**장점**
- 도구가 명확히 분리되어 있어 AI가 도구 선택이 쉬움
- 파트 라이브러리 기능으로 기존 기어 검색 가능
- SVG 프리뷰 지원

**단점**
- 로컬 MCP 서버 상시 실행 필요
- 서버 설정 및 환경 구성 초기 비용 존재
- `rishigundakaram` 서버는 generate 기능이 미완성

---

### 시나리오 C: Custom Mode + 기어 라이브러리 직접 참조

**구현 방식**
```
.clinerules/
├── 01-gear-library-api.md   # gear_library API 전체 문서화
└── 02-output-conventions.md # 출력 파일 명명 규칙

→ Cline이 API 문서를 컨텍스트로 읽고
→ gear_library를 import하는 스크립트 생성
→ 터미널에서 실행 → STEP/STL 출력
```

**API 문서 형식 (Cline이 읽기 좋은 형태)**

```markdown
# gear_library API Reference

## SpurGear
```python
from gear_library import SpurGear

gear = SpurGear(
    module: float,          # 모듈 (기어 크기 단위, 예: 1.0, 1.5, 2.0)
    teeth_number: int,      # 치수 (최소 17: 언더컷 방지)
    width: float,           # 치폭 (mm)
    bore_d: float,          # 보어 직경 (mm)
    pressure_angle: float = 20.0,  # 압력각 (도, 표준: 20)
    helix_angle: float = 0.0       # 나선각 (헬리컬 기어용)
)

# STEP 출력
gear.export_step("output.step")

# STL 출력
gear.export_stl("output.stl", tolerance=0.01)
```

**장점**
- 라이브러리 API가 명확하면 Cline이 일관된 코드 생성
- 라이브러리 내부에 파라미터 검증 로직 포함 가능
- MCP 서버 불필요

**단점**
- 기어 라이브러리 직접 구현 필요 (cq_gears 래핑 가능)
- 라이브러리 API 문서를 항상 최신 상태로 유지해야 함

---

## 3. 권장 아키텍처

### 결론: 시나리오 A + C 복합 (즉시 구현 가능)

```
┌─────────────────────────────────────────────────────────┐
│                    VS Code 환경                          │
│                                                          │
│  ┌──────────┐    대화      ┌──────────────────────┐     │
│  │  사용자  │ ──────────→ │  Cline (AI Agent)     │     │
│  └──────────┘             │                       │     │
│                           │  .clinerules/ 참조    │     │
│                           │  ├ 기어 도메인 지식   │     │
│                           │  ├ CadQuery 패턴      │     │
│                           │  └ API 문서           │     │
│                           └──────────┬────────────┘     │
│                                      │ 코드 생성         │
│                                      ↓                   │
│                           ┌──────────────────────┐     │
│                           │  gear_script.py       │     │
│                           │  (임시 생성 스크립트) │     │
│                           └──────────┬────────────┘     │
│                                      │ python 실행       │
│                                      ↓                   │
│                           ┌──────────────────────┐     │
│                           │  gear_library/        │     │
│                           │  ├ SpurGear           │     │
│                           │  ├ HelicalGear        │     │
│                           │  ├ BevelGear          │     │
│                           │  └ GearRack           │     │
│                           │  (cq_gears 래핑)      │     │
│                           └──────────┬────────────┘     │
│                                      │ 출력              │
│                                      ↓                   │
│                           ┌──────────────────────┐     │
│                           │  outputs/             │     │
│                           │  ├ gear_m2_z20.step  │     │
│                           │  └ gear_m2_z20.stl   │     │
│                           └──────────────────────┘     │
│                                      │                   │
│                                      ↓ show()           │
│                           ┌──────────────────────┐     │
│                           │  OCP CAD Viewer       │     │
│                           │  (VS Code 패널)       │     │
│                           └──────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### MCP 방식 추가 시 (시나리오 B 통합)

```
Cline ←→ cline_mcp_settings.json
              │
              └→ mcp-cadquery (stdio)
                      │
                      ├─ execute_cadquery_script → gear_library/
                      ├─ export_shape → outputs/*.step
                      ├─ export_shape_to_svg → previews/*.svg
                      └─ search_parts → gear_library/*.py
```

---

## 4. 기어 라이브러리 스킬화 방법

### 4.1 라이브러리 구조 (cq_gears 기반)

```python
# gear_library/__init__.py
# cq_gears를 래핑하여 Cline 친화적 API 제공

from .spur_gear import SpurGear
from .helical_gear import HelicalGear
from .bevel_gear import BevelGear
from .gear_rack import GearRack
from .planetary import PlanetaryGearset

__all__ = ['SpurGear', 'HelicalGear', 'BevelGear', 'GearRack', 'PlanetaryGearset']
```

```python
# gear_library/spur_gear.py
import cadquery as cq
from cq_gears import SpurGear as _SpurGear
from cadquery import exporters
from pathlib import Path
from typing import Optional

class SpurGear:
    """
    평기어 (Spur Gear) 생성기

    파라미터:
        module (float): 모듈 - 기어 크기 단위. 표준값: 1.0, 1.25, 1.5, 2.0, 2.5, 3.0
        teeth_number (int): 치수. 최소 17 (압력각 20° 기준 언더컷 방지)
        width (float): 치폭 (mm). 권장: module * 8 ~ module * 12
        bore_d (float): 보어(축구멍) 직경 (mm)
        hub_d (float): 허브 직경 (mm). 기본값: bore_d * 2
        hub_length (float): 허브 길이 (mm). 기본값: width * 0.5

    예시:
        gear = SpurGear(module=2.0, teeth_number=20, width=15.0, bore_d=10.0)
        gear.export_step("output.step")
    """

    def __init__(
        self,
        module: float,
        teeth_number: int,
        width: float,
        bore_d: float,
        hub_d: Optional[float] = None,
        hub_length: Optional[float] = None
    ):
        # 파라미터 검증
        if module <= 0:
            raise ValueError(f"모듈은 양수여야 합니다: {module}")
        if teeth_number < 12:
            raise ValueError(f"치수는 최소 12개 이상이어야 합니다: {teeth_number}")
        if teeth_number < 17:
            print(f"경고: 치수 {teeth_number}는 언더컷 발생 가능 (권장: 17 이상)")
        if width <= 0:
            raise ValueError(f"치폭은 양수여야 합니다: {width}")
        if bore_d <= 0:
            raise ValueError(f"보어 직경은 양수여야 합니다: {bore_d}")

        self.module = module
        self.teeth_number = teeth_number
        self.width = width
        self.bore_d = bore_d
        self.hub_d = hub_d or bore_d * 2
        self.hub_length = hub_length or width * 0.5

        # 계산 속성
        self.pitch_diameter = module * teeth_number
        self.outside_diameter = module * (teeth_number + 2)

        # cq_gears 객체 생성
        self._gear = _SpurGear(
            module=module,
            teeth_number=teeth_number,
            width=width,
            bore_d=bore_d,
            hub_d=self.hub_d,
            hub_length=self.hub_length
        )

        # CadQuery Workplane 생성
        self._result = cq.Workplane('XY').gear(self._gear)

    def export_step(self, output_path: str) -> str:
        """STEP 파일로 내보내기"""
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        exporters.export(self._result, output_path)
        return output_path

    def export_stl(self, output_path: str, tolerance: float = 0.01) -> str:
        """STL 파일로 내보내기"""
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        exporters.export(self._result, output_path, tolerance=tolerance)
        return output_path

    def show_info(self) -> dict:
        """기어 사양 출력"""
        return {
            "type": "Spur Gear",
            "module": self.module,
            "teeth_number": self.teeth_number,
            "pitch_diameter_mm": self.pitch_diameter,
            "outside_diameter_mm": self.outside_diameter,
            "width_mm": self.width,
            "bore_d_mm": self.bore_d
        }
```

### 4.2 .clinerules 기어 도메인 지식 주입

```markdown
# .clinerules/01-gear-domain.md

## 기어 설계 도메인 지식

### 기어 파라미터 표준값
- **모듈 (Module)**: 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0 (ISO 표준)
- **압력각 (Pressure Angle)**: 20° (표준), 14.5° (구형), 25° (고강도)
- **최소 치수**: 17개 (20° 압력각 기준 언더컷 방지)
- **치폭 권장**: module × 8 ~ module × 12

### 기어 용어 → 파라미터 매핑
- "모듈 2짜리" → module=2.0
- "20치 기어" / "치수 20개" → teeth_number=20
- "치폭 15mm" → width=15.0
- "축경 10mm" / "10mm 축" → bore_d=10.0
- "헬리컬" → HelicalGear (helix_angle 필요)
- "베벨" → BevelGear (pitch_angle 필요)

### 기어쌍 설계 규칙
- 두 기어의 모듈은 동일해야 함
- 중심거리 = (pitch_diameter1 + pitch_diameter2) / 2
- pitch_diameter = module × teeth_number

### 파일 명명 규칙
- STEP: `outputs/gear_{type}_m{module}_z{teeth}.step`
- STL: `outputs/gear_{type}_m{module}_z{teeth}.stl`
- 예: `outputs/gear_spur_m2_z20.step`
```

```markdown
# .clinerules/02-cadquery-patterns.md

## CadQuery 기어 코드 패턴

### 기본 사용 패턴
```python
from gear_library import SpurGear

# 기어 생성
gear = SpurGear(
    module=2.0,
    teeth_number=20,
    width=15.0,
    bore_d=10.0
)

# 사양 확인
import json
print(json.dumps(gear.show_info(), indent=2, ensure_ascii=False))

# STEP 출력 (기본)
gear.export_step("outputs/gear_spur_m2_z20.step")

# STL 출력 (3D 프린팅용)
gear.export_stl("outputs/gear_spur_m2_z20.stl")

# OCP CAD Viewer로 시각화 (VS Code에서)
from ocp_vscode import show
show(gear._result)
```

### 오류 처리 패턴
- ValueError 발생 시: 파라미터 범위 확인 후 수정
- ImportError 발생 시: `pip install git+https://github.com/meadiode/cq_gears.git@main`
- 언더컷 경고 발생 시: teeth_number를 17 이상으로 조정
```

### 4.3 워크플로우 파일

```markdown
# .clinerules/workflows/generate-gear.md

# 기어 생성 워크플로우

## 단계
1. 사용자 요청에서 기어 파라미터 추출 (module, teeth_number, width, bore_d, gear_type)
2. 누락된 파라미터는 도메인 지식 기반 기본값 적용
3. gear_library를 사용하는 Python 스크립트 생성
4. outputs/ 디렉토리 존재 확인
5. `python gear_generator.py` 실행
6. 생성된 파일 확인 및 사용자에게 결과 보고
7. OCP CAD Viewer로 시각화 (show() 호출)
```

---

## 5. OCP CAD Viewer 연동

### 설치

```bash
# VS Code에서
# Extension: "OCP CAD Viewer" (bernhard-42.ocp-cad-viewer) 설치

# Python 환경에서
pip install ocp-vscode
```

### Cline 워크플로우에서 시각화

```python
# 기어 생성 스크립트 끝에 추가
from ocp_vscode import show, show_object

# 단일 기어 표시
show(gear._result)

# 기어쌍 표시
show_object(gear1._result, name="driving_gear")
show_object(gear2._result, name="driven_gear")
```

### 자동 갱신 워크플로우

OCP CAD Viewer는 파일 저장 시 자동 갱신을 지원한다. Cline이 스크립트를 생성하고 실행하면 VS Code 패널에서 즉시 3D 모델이 표시된다.

### Jupyter 셀 방식 (선택적)

```python
# %% 마커로 셀 구분 (VS Code Jupyter 모드)
# %% [cell 1] 파라미터 설정
module = 2.0
teeth_number = 20

# %% [cell 2] 기어 생성 및 시각화
from gear_library import SpurGear
from ocp_vscode import show

gear = SpurGear(module=module, teeth_number=teeth_number, width=15.0, bore_d=10.0)
show(gear._result)
```

---

## 6. 단계별 구현 가이드

### Phase 1: 기반 환경 구성 (1~2일)

```bash
# 1. CadQuery 및 cq_gears 설치
conda create -n cadquery python=3.11
conda activate cadquery
pip install cadquery
pip install git+https://github.com/meadiode/cq_gears.git@main
pip install ocp-vscode

# 2. 프로젝트 디렉토리 생성
mkdir -p my-gear-project/{gear_library,outputs,.clinerules/workflows}
cd my-gear-project

# 3. VS Code에서 OCP CAD Viewer 확장 설치
```

### Phase 2: 기어 라이브러리 구현 (2~3일)

```
gear_library/
├── __init__.py
├── base_gear.py        # 공통 내보내기 메서드
├── spur_gear.py        # 평기어
├── helical_gear.py     # 헬리컬 기어
├── bevel_gear.py       # 베벨 기어
├── gear_rack.py        # 기어 랙
└── validators.py       # 파라미터 검증 모듈
```

### Phase 3: .clinerules 구성 (1일)

```
.clinerules/
├── 01-gear-domain.md       # 기어 설계 도메인 지식
├── 02-cadquery-patterns.md # CadQuery 코드 패턴
├── 03-output-conventions.md # 출력 규칙
└── workflows/
    └── generate-gear.md    # /generate-gear 워크플로우
```

### Phase 4: MCP 서버 통합 (선택, 1일)

```bash
# bertvanbrakel/mcp-cadquery 설치
git clone https://github.com/bertvanbrakel/mcp-cadquery
cd mcp-cadquery
./server_stdio.sh  # 첫 실행 (자동 venv 구성)

# Cline MCP 설정에 추가
# Settings > MCP Servers > Configure
```

### Phase 5: 테스트 및 검증 (1일)

Cline에게 아래와 같이 요청하여 전체 파이프라인 검증:

```
"모듈 2, 치수 20개의 평기어를 만들어줘.
 치폭은 16mm, 축경은 10mm로 해줘.
 STEP 파일로 저장하고 OCP CAD Viewer로 보여줘."
```

---

## 7. 필요한 파일/컴포넌트 목록

| 구성요소 | 파일 | 설명 |
|----------|------|------|
| 기어 라이브러리 | `gear_library/*.py` | cq_gears 기반 래퍼 |
| Cline 도메인 지식 | `.clinerules/01-gear-domain.md` | 기어 파라미터 표준, 매핑 규칙 |
| Cline 코드 패턴 | `.clinerules/02-cadquery-patterns.md` | CadQuery 사용 패턴 |
| 워크플로우 | `.clinerules/workflows/generate-gear.md` | 기어 생성 자동화 흐름 |
| 출력 디렉토리 | `outputs/` | STEP/STL 파일 저장 |
| MCP 설정 (선택) | `cline_mcp_settings.json` | mcp-cadquery 서버 연결 |

---

## 근거 출처

- [Cline GitHub Repository](https://github.com/cline/cline) - Cline 공식 소스코드 및 기능 명세
- [Cline Documentation](https://docs.cline.bot/) - MCP 통합, 워크플로우, .clinerules 문서
- [Cline Auto Approve & YOLO Mode](https://docs.cline.bot/features/auto-approve) - 터미널 자동 실행 설정
- [bertvanbrakel/mcp-cadquery](https://github.com/bertvanbrakel/mcp-cadquery) - 가장 성숙한 CadQuery MCP 서버 (5개 도구, 파트 라이브러리)
- [rishigundakaram/cadquery-mcp-server](https://github.com/rishigundakaram/cadquery-mcp-server) - Claude Code 특화 MCP 서버 (generate는 stub 상태)
- [rishigundakaram/cad-query-workspace](https://github.com/rishigundakaram/cad-query-workspace) - Claude Code 워크스페이스 예제
- [meadiode/cq_gears](https://github.com/meadiode/cq_gears) - CadQuery 기반 인볼류트 기어 파라메트릭 라이브러리
- [bernhard-42/vscode-ocp-cad-viewer](https://github.com/bernhard-42/vscode-ocp-cad-viewer) - VS Code OCP CAD Viewer 확장
- [OCP CAD Viewer - VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=bernhard-42.ocp-cad-viewer) - 확장 설치 페이지
- [Creating Parametric Gear Models with Streamlit and CadQuery](https://splinecloud.com/blog/creating-parametric-gear-models-with-streamlit-and-cadquery/) - CadQuery 기어 생성 코드 패턴
- [Cline Workflows Documentation](https://docs.cline.bot/customization/workflows) - 워크플로우 형식 및 활용법
- [Cline .clinerules Blog Post](https://cline.bot/blog/clinerules-version-controlled-shareable-and-ai-editable-instructions) - .clinerules 활용 방법
- [CAD-Query MCP Server - Awesome MCP Servers](https://mcpservers.org/servers/rishigundakaram/cadquery-mcp-server) - MCP 서버 목록
- [DeepWiki: STL Generation with cq-cli](https://deepwiki.com/rishigundakaram/cadquery-mcp-server/4.1-stl-generation-with-cq-cli) - STL 생성 내부 구현
