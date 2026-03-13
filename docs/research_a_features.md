# CadQuery 기능 범위 조사 결과

> 조사일: 2026-03-13 | 출처: 공식 문서 직접 참조

## 요약

CadQuery는 OCCT(Open Cascade Technology) 커널 기반의 Python 파라메트릭 3D CAD 라이브러리로, 기계 부품·PCB 케이스 수준의 정밀 엔지니어링 모델링에 매우 적합하다. Workplane 기반 체이닝 API와 BREP(Boundary Representation) 방식으로 높은 코드 효율성을 제공하며, STEP·STL·DXF 등 전문 CAD 포맷을 완벽 지원한다. 다만 유기적 자유 곡면(organic/sculptural shapes)과 메쉬 직접 편집은 구조적 한계가 있고, 나사산·기어 같은 기계 표준 부품은 별도 라이브러리(cq-kit, cadquery-contrib 등)에 의존한다.

---

## 핵심 기능 (✅ 지원 / ⚠️ 부분 지원 / ❌ 미지원)

| 기능 | 상태 | 비고 |
| --- | --- | --- |
| Primitive shapes (box, sphere, cylinder, wedge) | ✅ | Workplane에 직접 내장 |
| Boolean operations (union, cut, intersect) | ✅ | `union()`, `cut()`, `intersect()` |
| Extrude | ✅ | `extrude()`, `twistExtrude()` |
| Revolve | ✅ | `revolve()` |
| Sweep | ✅ | `sweep()` |
| Loft | ✅ | `loft()` |
| Fillet / Chamfer | ✅ | `fillet()`, `chamfer()` |
| Shell | ✅ | `shell()` |
| Workplane 기반 스케치 | ✅ | 핵심 패러다임 |
| Sketch API (독립형) | ✅ | 제약조건 기반 포함 (실험적) |
| Assembly (부품 조립) | ✅ | 제약 조건 8종 |
| 3D Text | ✅ | `Compound.makeText()` |
| NURBS / Spline | ✅ | `spline()`, `parametricCurve()`, `parametricSurface()` |
| Ruled Surface / NSided Surface | ✅ | `makeRuledSurface()`, `makeNSidedSurface()` |
| Import: STEP, DXF | ✅ | DXF는 2D 프로필 import 용도 |
| Export: STEP, STL, SVG, DXF, AMF, 3MF, VRML, glTF | ✅ | DXF export는 2D 단면만 |
| Thread (나사산) 직접 생성 | ⚠️ | 내장 없음, 커뮤니티 라이브러리 필요 |
| 기어 (Gear) 직접 생성 | ⚠️ | 내장 없음, 외부 레시피 필요 |
| 유기적 자유 곡면 (Organic shapes) | ⚠️ | NURBS 제한적 지원, 조각 수준은 어려움 |
| 메쉬 직접 편집 | ❌ | BREP 기반으로 구조적으로 미지원 |
| IGES Import/Export | ❌ | 공식 문서에서 미언급 |
| 파라메트릭 데이터 보존 (STEP 등) | ❌ | 외부 포맷 저장 시 파라메트릭 정보 손실 |

---

## 고급 기능 상세

### Assembly 시스템

- 8종 제약 조건: `Point`, `Axis`, `Plane`, `PointInPlane`, `PointOnLine`, `FixedPoint`, `FixedRotation`, `FixedAxis`
- 태그(tag) 기반 면/엣지 식별 후 `constrain()` → `solve()`로 위치 자동 계산
- 컴포넌트별 색상 지정 가능, STEP/glTF/XML 포맷으로 어셈블리 저장
- 실사례: V-slot 도어 조립체 (10개 컴포넌트, 15개 제약)

### Sketch API

- 3가지 구성 방식: 면(face) 기반, 엣지 기반, 제약조건 기반 (마지막은 실험적)
- Boolean 모드: add(`'a'`), subtract(`'s'`), intersect(`'i'`), replace(`'r'`), construction(`'c'`)
- 지원 제약: `FixedPoint`, `Coincident`, `Angle`, `Length`, `Distance`, `Radius`, `Orientation`, `ArcAngle`
- 제약 기반 스케치는 현재 선분·호만 지원 (다각형 등 미지원)

### Surface Geometry

- `spline()`, `parametricCurve()`: 자유 곡선
- `parametricSurface()`: 수식 기반 자유 곡면
- `makeRuledSurface()`: 두 엣지 사이 직선 규칙면
- `makeNSidedSurface()`: N개의 경계로 정의되는 곡면
- NURBS는 OCCT 수준에서 지원되나, Fluent API에서의 직접 제어는 제한적

### 3D Text

- `Compound.makeText(text, size, height, font, fontPath, kind, halign, valign, position)`으로 완전한 3D 텍스트 솔리드 생성 가능

### Import/Export 상세

| 포맷 | Import | Export | 비고 |
| --- | --- | --- | --- |
| STEP | ✅ | ✅ | 어셈블리 구조·색상 보존 |
| STL | ❌ | ✅ | tolerance, angularTolerance 조정 가능 |
| DXF | ✅ | ✅ | Import: 2D 프로필 / Export: 2D 단면만 |
| SVG | ❌ | ✅ | 투영 방향, 숨은선 표시 옵션 |
| AMF | ❌ | ✅ |  |
| 3MF | ❌ | ✅ |  |
| VRML | ❌ | ✅ |  |
| glTF / GLB | ❌ | ✅ | 웹 렌더링용 |
| TJS (ThreeJS) | ❌ | ✅ | JSON 메쉬 |
| XBF / XML (XCAF) | ✅ | ✅ | 내부 OCCT 어셈블리 포맷 |

---

## 기술적 한계

### OCCT 기반 구조적 제약

1. **BREP 전용**: 메쉬(폴리곤) 기반 편집 불가. STL import 미지원, 메쉬를 읽어 BREP으로 변환하는 워크플로우 없음
2. **파라메트릭 히스토리 없음**: OCCT는 히스토리 트리를 관리하지 않으므로, 생성 후 중간 단계 수정은 코드 재실행으로만 가능
3. **NURBS 노출 제한**: OCCT 내부에서 NURBS를 사용하지만 Fluent API 레벨에서 제어점 직접 편집은 불가

### 성능 한계

- 복잡한 Boolean 연산이 많아질수록 연산 시간이 급증 (OCCT 커널 특성)
- 수천 개 이상의 반복 feature(패턴) 생성 시 성능 저하 가능
- 고해상도 메쉬 출력(STL) 시 tolerance 값에 따라 파일 크기·생성 시간 편차 큼

### 유기적 형태(Organic Shapes) 처리

- `parametricSurface()`로 수학적으로 정의 가능한 곡면은 생성 가능
- Blender·ZBrush 수준의 자유로운 조각(sculpting), subdivision surface, 위상 변형은 불가
- 자유형 NURBS patch 편집 UI 없음 (코드로 제어점 좌표 계산 필요)

### 기타

- 제약 기반 Sketch는 실험적 상태, 선분·호 외 요소 미지원
- DXF export는 2D 단면만 지원 (3D 형상 직접 DXF export 불가)
- IGES 포맷 미지원
- 스레드(나사산)·기어 등 기계 표준 요소 내장 없음

---

## 실제 구현 가능 수준 (레벨 분류)

### Level 1 — 완전 지원 (권장 용도)

- 기계 부품: 브래킷, 샤프트, 플랜지, 하우징, 베어링 홀더
- PCB 인클로저/케이스: 스냅핏, 보스, 리브 포함 복잡한 인클로저
- 파이프·덕트 피팅: sweep 기반 복잡한 경로
- 프로파일 압출 부품: 알루미늄 프레임, DXF import 기반 단면
- 반복 패턴 부품: `rarray()`, `polarArray()` 기반 볼트 패턴 등

### Level 2 — 구현 가능 (추가 작업 필요)

- 나사산(Thread) 부품: `twistExtrude()` 조합 또는 `cq-kit` 라이브러리 사용
- 기어: involute 곡선을 spline으로 직접 계산하거나 외부 레시피 활용
- 건축 모델: 직선/곡선 기반 건물 외피, 구조재; 복잡한 파라메트릭 파사드
- 조립체 도면: Assembly API + STEP export로 완전한 조립 어셈블리

### Level 3 — 제한적 구현 (상당한 수작업 필요)

- 유기적 곡면 제품: 자동차 바디, 손잡이 등 — `parametricSurface()`로 수식 정의 필요
- 자유형 조각 형태: 엄밀히 수학적으로 기술할 수 없는 형태는 사실상 불가
- 의료/인체공학 모델: CT 데이터 기반 메쉬 편집 불가

### Level 4 — 미지원 (대체 도구 필요)

- 메쉬 기반 에셋 편집: 게임용 3D 오브젝트, 스캔 데이터 처리 → Blender 등 사용
- Subdivision Surface 모델링: 유기체, 캐릭터 → Blender/Maya
- 렌더링/애니메이션: CadQuery는 렌더러 없음

---

## 경쟁 도구 대비 포지션

### CadQuery vs OpenSCAD

| 항목 | CadQuery | OpenSCAD |
| --- | --- | --- |
| 언어 | Python (표준 생태계 활용) | OpenSCAD 전용 언어 |
| CAD 커널 | OCCT (NURBS, surface sewing) | CGAL (CSG 기반) |
| 코드량 | 적음 (지능적 feature 배치) | 많음 |
| STL/STEP 생성 속도 | 빠름 | 느림 |
| 고급 기하 (NURBS 등) | 지원 | 미지원 |
| 학습 곡선 | Python 알면 낮음 | 독자 언어 별도 학습 |
| GUI 에디터 | CQ-editor (별도) | 내장 |
| 커뮤니티/생태계 | 성장 중 | 성숙 |

### CadQuery vs build123d

build123d는 CadQuery의 **직접적인 진화형** 라이브러리이다.

| 항목 | CadQuery | build123d |
| --- | --- | --- |
| 기반 | OCCT Python 래퍼 | CadQuery 코드베이스 기반 |
| API 스타일 | 메서드 체이닝 (fluent API) | Python `with` context manager |
| 루프/조건문 삽입 | 체이닝 중단 없이 어려움 | 자유롭게 삽입 가능 |
| 선택(Selector) | 문자열 기반 | Python 리스트 필터/정렬 |
| IDE 지원 | 제한적 | Enum 기반 자동완성 향상 |
| 성숙도 | 안정적, 대규모 커뮤니티 | 활발히 개발 중 |
| 사용 권장 | 현재 프로덕션, 안정성 중시 | 새 프로젝트, Pythonic 코드 선호 |

**관계 요약**: build123d는 CadQuery의 핵심 OCCT 래퍼를 이어받아 API UX를 전면 재설계한 차세대 대안으로, CadQuery를 대체하려는 방향성을 가지고 있다.

---

## 근거 출처

| 항목 | URL |
| --- | --- |
| CadQuery 공식 문서 (개요) | https://cadquery.readthedocs.io/en/latest/ |
| API 레퍼런스 | https://cadquery.readthedocs.io/en/latest/apireference.html |
| Assembly 문서 | https://cadquery.readthedocs.io/en/latest/assy.html |
| Sketch 문서 | https://cadquery.readthedocs.io/en/latest/sketch.html |
| Import/Export 문서 | https://cadquery.readthedocs.io/en/latest/importexport.html |
| 기술 기초 (Primer) | https://cadquery.readthedocs.io/en/latest/primer.html |
| GitHub README | https://github.com/CadQuery/cadquery |
| build123d 공식 문서 | https://build123d.readthedocs.io/en/latest/introduction.html |
