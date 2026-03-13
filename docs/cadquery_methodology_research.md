# CadQuery 방법론 및 워크플로우 조사 결과

> 작성일: 2026-03-13
> 조사 방법: 공식 문서, GitHub 저장소, 학술 논문, 커뮤니티 자료 웹 수집

---

## 요약

CadQuery는 Python 기반의 파라메트릭 3D CAD 스크립팅 프레임워크로, OpenCASCADE Technology(OCCT) 커널 위에서 동작한다. 코드로 3D 모델을 정의하는 "Code-CAD" 패러다임에서 현재 가장 성숙한 두 선택지는 **CadQuery**와 파생 프로젝트인 **build123d**이다.

2025~2026년 기준 주요 트렌드:
- **AI/LLM 연계 급증**: Text-to-CadQuery, CAD-Coder, CAD-Recode 등 자연어→3D 모델 변환 연구가 활발히 진행 중
- **build123d의 빠른 채택**: 더 Pythonic한 인터페이스와 생산 환경 적합성으로 신규 프로젝트에서 채택 증가
- **VS Code + OCP CAD Viewer**가 표준 개발 환경으로 자리잡는 추세
- **CadQuery MCP Server** 등장: AI 어시스턴트(Claude 등)가 직접 CadQuery 스크립트를 실행하는 통합 워크플로우 등장

---

## 추천 개발 환경 셋업

### 1. 설치 방법

**Conda 방식 (권장)**
```bash
conda create -n cadquery
conda activate cadquery
mamba install -c conda-forge cadquery
```

**pip 방식**
```bash
python -m venv .venv
source .venv/bin/activate
pip install cadquery
```

**최신 개발 버전**
```bash
pip install git+https://github.com/CadQuery/cadquery.git
```

Python 3.9 이상 필요. 의존성이 복잡하므로 conda/mamba 사용이 안정적이다.

### 2. 개발 환경 옵션 비교

| 환경 | 특징 | 추천 대상 |
|------|------|-----------|
| **VS Code + OCP CAD Viewer** | 실시간 3D 렌더링, 측정 도구, 디버깅 통합 | 일반 개발자 (현재 표준) |
| **CQ-editor** | PyQT 기반 공식 GUI, 내장 디버거, 3D 뷰어 | CadQuery 입문자 |
| **JupyterLab** | 인터랙티브 실험, `display()` 함수 지원 | 탐색적 설계, 교육 |
| **FreeCAD Workbench** | CadQuery 스크립트를 FreeCAD에서 렌더링 | FreeCAD 병행 사용자 |

### 3. VS Code + OCP CAD Viewer 셋업 (권장)

1. VS Code Marketplace에서 "OCP CAD Viewer" 검색 설치 (bernhard-42)
2. 사이드바 OCP 아이콘 클릭 → Quickstart 버튼 선택
3. 자동으로 `OCP, ipykernel, jupyter_client, ocp_tessellate, ocp_vscode` 설치
4. pip 수동 설치: `pip install ocp-vscode` 또는 `uv add ocp-vscode`

**주요 기능**: 실시간 3D 렌더링, 거리/각도 측정, 지브라 모드(표면 품질 확인), 애니메이션 제어, GIF 저장

---

## 핵심 워크플로우 패턴

### 1. 코드 기반 파라메트릭 모델링 플로우

CadQuery의 기본 패턴은 **Workplane → Sketch → 3D Operation** 체인이다:

```python
import cadquery as cq

# 파라미터를 상단에 정의
width = 50
height = 30
thickness = 5
hole_diameter = 8

# Fluent API 체이닝
result = (
    cq.Workplane("XY")
    .box(width, height, thickness)
    .faces(">Z")
    .workplane()
    .hole(hole_diameter)
    .fillet(1.5)
)

# 내보내기
cq.exporters.export(result, "part.step")
cq.exporters.export(result, "part.stl")
```

**3가지 API 레이어**:
1. **Fluent API** (Workplane 클래스) - 가장 직관적, 메서드 체이닝
2. **Direct API** - Shape, Solid, Face, Edge 등 위상학적 클래스
3. **OCCT API** - 최하위 레벨 C++ 바인딩

레이어 간 전환:
```python
solid = cq.Workplane().box(10, 5, 5).val()        # Fluent → Direct
wp = cq.Workplane(obj=solid)                        # Direct → Fluent
```

### 2. 어셈블리 및 제약조건 기반 설계

```python
assy = (
    cq.Assembly()
    .add(part1, name="base")
    .add(part2, name="cap")
    .constrain("base@faces@>Z", "cap@faces@<Z", "Axis")
    .solve()
)
```

파라미터(w, d, h) 변경 시 제약조건으로 위치가 자동 재계산된다.

### 3. 반복 설계 수정 사이클

```
파라미터 변경 → 스크립트 실행 → OCP CAD Viewer 자동 갱신 → 검증 → 내보내기
```

VS Code에서 파일 저장 시 OCP CAD Viewer가 자동으로 모델을 갱신한다. CQ-editor는 별도 "Render" 버튼이 필요하다.

### 4. Git 버전 관리와 3D 모델 관리

Code-CAD의 핵심 장점: **순수 텍스트 Python 파일이므로 git diff, pull request, code review가 그대로 적용된다.**

권장 저장소 구조:
```
project/
├── parts/
│   ├── housing.py          # 각 부품을 별도 파일로
│   ├── lid.py
│   └── bracket.py
├── assemblies/
│   └── main_assembly.py
├── params/
│   └── dimensions.py       # 공유 파라미터 모듈
├── output/                 # .gitignore에 추가 (생성 파일)
│   ├── *.step
│   └── *.stl
└── tests/
    └── test_geometry.py
```

`output/` 디렉토리의 STEP/STL 파일은 git에서 제외하고 CI/CD로 자동 생성한다.

**GitHub Actions 연동**: `ocp-action`을 사용하면 PR 시 자동으로 모델을 렌더링하여 시각적 변경 확인이 가능하다.

### 5. CLI 기반 자동화 (CI/CD)

```bash
# cq-cli를 이용한 배치 변환
cq-cli --codec step --infile part.py --outfile part.step
cq-cli --codec stl --infile part.py --outfile part.stl
```

---

## 출력 및 연계 워크플로우

### 지원 출력 형식

| 형식 | 용도 | 내보내기 방법 |
|------|------|---------------|
| **STEP** | CAD 소프트웨어 교환, 정밀 엔지니어링 | `exporters.export(result, "part.step")` |
| **STL** | 3D 프린팅 | `exporters.export(result, "part.stl")` |
| **DXF** | 레이저 커팅, CNC, 2D 도면 | `DxfDocument` 클래스 또는 `exporters.export()` |
| **3MF** | 차세대 3D 프린팅 형식 | `exporters.export()` |
| **VRML** | 웹 3D 표시 | `exporters.export()` |
| **AMF** | 3D 프린팅 메타데이터 포함 | `exporters.export()` |
| **SVG** | 2D 투영 도면 | `toSvg()`, `exportSvg()` |

### 연계 워크플로우

**STEP → Fusion 360 / FreeCAD**
- CadQuery에서 STEP 내보내기 후 직접 가져오기
- 역방향: STEP 파일을 `importers.importStep()`으로 로드하여 CadQuery에서 추가 가공 가능

**STL → 3D 프린팅**
- PrusaSlicer, Cura 등 슬라이서로 직접 가져오기
- 3MF 형식이 메타데이터(재질, 색상) 포함으로 더 권장

**DXF → 레이저 커팅/CNC**
- `DxfDocument` 클래스로 레이어별 2D 프로파일 내보내기
- 역방향: `importers.importDXF()`로 DXF를 CadQuery로 가져오기

**Blender 연동**
- **BlendQuery** (`uki-dev/blendquery`): CadQuery와 build123d를 Blender에 통합
- **ocp-freecad-cam**: FreeCAD CAM 워크플로우 연동

---

## 실제 사용 사례

### 오픈소스 프로젝트 사례

| 프로젝트 | 설명 |
|---------|------|
| **FxBricks** | Lego 열차 시스템 제품 개발 파이프라인 전체를 CadQuery로 자동화 |
| **Hexidor** | 보드게임 디자인(헥사고날 타일 등)에 파라메트릭 모델 활용 |
| **cq-gridfinity** | Gridfinity 호환 보관함/베이스플레이트 파라메트릭 생성기 |
| **cq_warehouse** | 볼트, 너트, 베어링 등 표준 기계 부품 온디맨드 생성 라이브러리 |
| **cq_gears** | 인볼류트 기어, 헬리컬 기어 등 파라메트릭 기어 생성기 |
| **cq-electronics** | PCB 하우징, 커넥터 등 전자 부품 모델 라이브러리 |

### 기계 설계 자동화 사례

- **금형 자동화**: 케이블용 실리콘 금형을 파라미터(직경, 길이)만 바꿔 자동 생성
- **인클로저 자동화**: 전자 제품 케이스를 PCB 치수 기반으로 자동 생성
- **스핀들 어셈블리**: 복잡한 기계 어셈블리를 제약조건 기반으로 구성

### AI/LLM 연계 사례 (2025~2026 최신)

**Text-to-CadQuery (arXiv 2505.06507)**
- 자연어 → CadQuery 코드 자동 생성
- 170,000개 텍스트-CadQuery 쌍 데이터셋으로 LLM 파인튜닝
- 자동 피드백 루프(실행 → 오류 수정 → 형상 검증)로 실행 성공률 53% → 85%로 향상
- Chamfer Distance 48.6% 감소, 정확 일치율 69.3% 달성

**CAD-Coder (MIT, arXiv 2505.14646)**
- 오픈소스 Vision-Language Model
- 실물 3D 프린팅 객체 사진 → CadQuery 코드 생성
- 163,000개 CAD 이미지-코드 쌍 학습, 100% 유효 구문율 달성

**CAD-Recode**
- 포인트 클라우드(3D 스캔) → CadQuery 코드 역엔지니어링
- LLM + 포인트 클라우드 프로젝터 end-to-end 학습

**CadQuery MCP Server**
- Claude, ChatGPT 등 AI 어시스턴트가 MCP(Model Context Protocol)를 통해 CadQuery 스크립트 직접 실행
- 자연어 대화로 3D 모델을 생성하고 렌더링 결과를 즉시 확인하는 워크플로우

---

## 베스트 프랙티스

### 1. 코드 구조화

```python
# ✅ 권장: 파라미터를 상단에 모아서 관리
WIDTH = 50.0
HEIGHT = 30.0
THICKNESS = 5.0
FILLET_RADIUS = 1.5

def make_part(width=WIDTH, height=HEIGHT, thickness=THICKNESS):
    """파라미터를 함수 인자로 노출하면 외부에서 변형 용이"""
    return (
        cq.Workplane("XY")
        .box(width, height, thickness)
        .fillet(FILLET_RADIUS)
    )

# 공유 파라미터는 별도 모듈로
# from params.dimensions import STANDARD_FILLET, BOLT_HOLE_DIAMETER
```

### 2. 파라미터 관리 전략

- 상수는 UPPER_CASE 네이밍으로 최상단 정의
- 공유 치수는 `params/dimensions.py` 같은 별도 모듈로 분리
- 함수 인자로 파라미터를 노출하면 라이브러리로 재사용 가능

### 3. 디버깅과 단계별 검증

```python
# ✅ 긴 체인 대신 단계별 분리로 중간 상태 확인
base = cq.Workplane("XY").box(50, 30, 5)
with_holes = base.faces(">Z").hole(8)
final = with_holes.fillet(1.5)

# OCP CAD Viewer에서 각 단계 변수를 개별로 표시 가능
```

### 4. 흔한 실수와 회피법

| 실수 | 올바른 방법 |
|------|------------|
| `sketch.arc(p1=(1,2), p2=(2,3), p3=(3,4))` (키워드 인자) | `sketch.arc((1,2), (2,3), (3,4))` (위치 인자 사용) |
| STL만 내보내기 | STEP 우선 내보내기 (정밀도 유지), STL은 3D 프린팅용으로만 |
| 파라미터 하드코딩 | 모든 치수를 변수로 정의 |
| 단일 거대 스크립트 | 부품별 파일 분리, 어셈블리에서 import |
| output 파일을 git에 커밋 | `.gitignore`에 `output/` 추가, CI/CD로 자동 생성 |

### 5. 테스트 및 검증

```python
# 기하학적 검증 예시
import pytest

def test_part_volume():
    part = make_part(width=50, height=30, thickness=5)
    # BoundingBox로 치수 검증
    bb = part.val().BoundingBox()
    assert abs(bb.xlen - 50) < 0.01
    assert abs(bb.ylen - 30) < 0.01

def test_part_valid():
    part = make_part()
    # 유효한 Solid인지 확인
    assert part.val().isValid()
```

### 6. 성능 고려사항

- 복잡한 불리언 연산은 OCCT 내부에서 처리되므로 파이썬 레벨 최적화보다 모델링 전략이 중요
- 필렛/챔퍼는 마지막 단계에 적용 (중간 적용 시 이후 연산에서 오류 가능성)
- 어셈블리 제약조건 `solve()`는 비용이 높으므로 필요한 경우에만 사용

---

## build123d 선택 가이드

### 핵심 차이점 비교

| 항목 | CadQuery | build123d |
|------|----------|-----------|
| **기원** | 원조 Python Code-CAD | CadQuery에서 파생, 독립 리팩토링 |
| **인터페이스** | Fluent API (메서드 체이닝) | 대수적 API (연산자 오버로딩) + Builder Mode |
| **상태 관리** | Workplane이 상태를 추적 | 최소한의 내부 상태 |
| **Python 친화성** | 중간 (일부 비Pythonic 패턴) | 높음 (PEP 8, mypy, pylint 완전 준수) |
| **확장성** | monkey patching 방식 | 서브클래싱 + 함수형 합성 |
| **OCP 접근** | 제한적 | 상세 접근 가능 |
| **문서화** | 성숙, 풍부한 예제 | 성장 중 |
| **커뮤니티 모멘텀** | 안정적 | 빠르게 성장 |

### build123d 코드 스타일 예시

```python
from build123d import *

# 대수적 모델링
with BuildPart() as part:
    Box(50, 30, 5)
    fillet(part.edges().filter_by(Axis.Z), radius=1.5)
    with Locations(part.faces().filter_by(Axis.Z)):
        CounterBoreHole(radius=4, counter_bore_radius=6, counter_bore_depth=2)
```

### 선택 가이드라인

**CadQuery를 선택해야 할 때:**
- 이미 CadQuery 코드베이스나 라이브러리(`cq_warehouse` 등)에 투자한 경우
- 빠른 프로토타이핑이 목적인 경우
- STEP 파일 임포트 후 추가 가공 워크플로우가 필요한 경우
- 레거시 코드와 호환성이 중요한 경우
- AI/LLM 연계 시 (현재 대부분의 연구가 CadQuery 기반)

**build123d를 선택해야 할 때:**
- 신규 프로젝트를 시작하는 경우 (특히 생산 환경)
- CNC 가공, 레이저 커팅 등 고정밀 제조 워크플로우
- 팀 프로젝트에서 코드 품질과 타입 안전성이 중요한 경우
- 복잡한 형상에서 OCP 레벨 접근이 필요한 경우
- Python 생태계(mypy, pylint, 타입 힌트) 완전 통합이 필요한 경우

**실용적 권고 (추정):**
- 2026년 시점에서 신규 프로젝트라면 **build123d를 우선 검토**하되, `cq_warehouse` 같은 풍부한 부품 라이브러리가 필요하다면 CadQuery를 선택
- 두 라이브러리는 동일한 OCCT 커널 기반이므로 STEP 파일을 통해 상호 운용 가능
- LLM/AI 연계 목적이라면 현재 연구 생태계가 CadQuery 중심이므로 **CadQuery가 유리**

---

## 근거 출처

- [CadQuery 공식 문서](https://cadquery.readthedocs.io/en/latest/)
- [CadQuery GitHub](https://github.com/CadQuery/cadquery)
- [build123d GitHub](https://github.com/gumyr/build123d)
- [awesome-cadquery](https://github.com/CadQuery/awesome-cadquery)
- [Build123d vs CadQuery 비교 - Oreate AI](https://www.oreateai.com/blog/build123d-vs-cadquery-navigating-the-future-of-python-cad-modeling/b9e17e3134422786a0ab67c0a6d1eeda)
- [CadQuery Python CAD 생태계 - Tim Derzhavets](https://timderzhavets.com/blog/cadquery_python_cad_ecosystem/)
- [Text-to-CadQuery 논문 (arXiv 2505.06507)](https://arxiv.org/html/2505.06507v1)
- [CAD-Coder 논문 (arXiv 2505.14646)](https://arxiv.org/html/2505.14646)
- [OCP CAD Viewer VS Code 확장](https://marketplace.visualstudio.com/items?itemName=bernhard-42.ocp-cad-viewer)
- [build123d 외부 도구 문서](https://build123d.readthedocs.io/en/latest/external.html)
- [cadquery GitHub Topics](https://github.com/topics/cadquery)
- [CadQuery KoalaWiki Overview](https://opendeep.wiki/CadQuery/cadquery/overview)
