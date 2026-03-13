# CadQuery 기어 설계 조사 결과

> 조사일: 2026-03-13 | 출처: cq_gears GitHub, 공식 문서, 대안 라이브러리 직접 분석

## 요약

CadQuery 생태계에는 `cq_gears`(CadQuery 전용), `py_gearworks`(build123d 기반), `bd_warehouse`(스퍼기어 한정) 등 실용적인 인볼류트 기어 생성 라이브러리가 존재하며, 스퍼/헬리컬/베벨/웜/유성기어 등 주요 기어 타입을 파라미터 입력만으로 3D 솔리드로 생성할 수 있다. 인볼류트 치형은 수식 기반으로 계산되나 스플라인 근사(20포인트)를 사용하므로 3D 프린팅·시뮬레이션 용도로는 충분하나, AGMA 고정밀 CNC 가공 용도에는 전문 CAD/CAM 검증이 추가로 필요하다.

---

## cq_gears 지원 기어 타입 및 파라미터

### 지원 기어 타입 (v0.51)

| 기어 타입 | 클래스명 | 소스 파일 |
|-----------|----------|-----------|
| 스퍼 기어 | `SpurGear` | `spur_gear.py` |
| 헬리컬 기어 | `SpurGear(helix_angle≠0)` | `spur_gear.py` |
| 헤링본 기어 | `HerringboneGear` | `spur_gear.py` |
| 링 기어 (내부) | `RingGear` | `ring_gear.py` |
| 유성 기어셋 | `PlanetaryGearset` | `ring_gear.py` |
| 베벨 기어 (직선/헬리컬) | `BevelGear` | `bevel_gear.py` |
| 웜 기어 | `Worm` | `worm_gear.py` |
| 기어 랙 | `GearRack` | `rack_gear.py` |
| 교차 헬리컬 기어 | `CrossedHelicalGear` | `crossed_helical_gear.py` |

### SpurGear 파라미터

| 파라미터 | 필수/선택 | 기본값 | 설명 |
|----------|-----------|--------|------|
| `module` | 필수 | - | 기어 모듈 (mm) |
| `teeth_number` | 필수 | - | 잇수 |
| `width` | 필수 | - | 치폭 (mm) |
| `pressure_angle` | 선택 | 20.0° | 압력각 |
| `helix_angle` | 선택 | 0.0° | 헬리컬각 (0이면 스퍼기어) |
| `clearance` | 선택 | 0.0 | 치저 여유 |
| `backlash` | 선택 | 0.0 | 백래시 |
| `addendum_coeff` | 선택 | 1.0 | 이끝 계수 |
| `dedendum_coeff` | 선택 | 1.25 | 이뿌리 계수 |
| `bore_d` | 빌드옵션 | - | 보어 지름 |
| `hub_d` | 빌드옵션 | - | 허브 지름 |
| `hub_length` | 빌드옵션 | - | 허브 길이 |

---

## 예제 코드

### 기본 스퍼기어

```python
import cadquery as cq
from cq_gears import SpurGear

spur_gear = SpurGear(module=1.0, teeth_number=19, width=5.0, bore_d=5.0)
wp = cq.Workplane('XY').gear(spur_gear)
cq.exporters.export(wp, 'spur_gear.step')
```

### 헬리컬 기어

```python
from cq_gears import SpurGear

helical_gear = SpurGear(
    module=1.0,
    teeth_number=19,
    width=10.0,
    helix_angle=30.0,
    pressure_angle=20.0,
    backlash=0.05,
    bore_d=5.0
)
wp = cq.Workplane('XY').gear(helical_gear)
```

### 맞물리는 기어 쌍 어셈블리

```python
import cadquery as cq
from cq_gears import SpurGear

spur_gear = SpurGear(module=1.0, teeth_number=13, width=5.0, bore_d=5.0)

wp = (
    cq.Workplane('XY')
    .rarray(
        xSpacing=spur_gear.r0 * 2.0,  # r0 = 피치 반지름
        ySpacing=1.0,
        xCount=4,
        yCount=1,
        center=False
    )
    .gear(spur_gear)
)
```

---

## 정밀도 및 제조 적합성

### 인볼류트 치형 계산 방식
- 기초원 반경: `r_base = r_pitch × cos(pressure_angle)`
- 인볼류트 함수: `inv(α) = tan(α) - α` 적용
- 치형 곡선: **20개 포인트 B-스플라인 근사** 후 OCCT 솔리드 생성
- 백래시 수식: `s0 = m × (π/2 - backlash × tan(α))`

### 제조 적합성

| 용도 | 적합성 | 비고 |
|------|--------|------|
| 3D 프린팅 (FDM) | ✅ 적합 | 모듈 ≥ 1.5, 잇수 ≥ 20 권장, 백래시 0.15~0.25mm |
| 3D 프린팅 (SLA/SLS) | ✅ 적합 | 고해상도로 더 작은 모듈도 가능 |
| 시뮬레이션/렌더링 | ✅ 적합 | STEP/STL 내보내기 지원 |
| 프로토타입 CNC 가공 | ⚠️ 조건부 | 치형 기하는 정확하나 공차 설정은 수동 필요 |
| 정밀 CNC (AGMA Q8 이상) | ❌ 부적합 | KISSsoft, Romax 등 전용 도구 필요 |

---

## 한계 및 대안

### cq_gears 한계
1. **라이브러리 안정성**: v0.51, "진행 중이며 다소 불안정할 수 있음" 명시
2. **CadQuery 버전 의존성**: 릴리즈 2.1 미지원, 개발 버전 필수
3. **언더컷 미처리**: 잇수 < 17인 소치수 기어에서 별도 검증 필요
4. **강도 계산 부재**: Lewis 굽힘 응력, AGMA 피팅 계산 없음
5. **20포인트 스플라인**: 초정밀 가공 시 분해능 제한 가능

### 대안 라이브러리 비교

| 라이브러리 | 기반 | 주요 강점 | 약점 |
|-----------|------|----------|------|
| `cq_gears` | CadQuery | 가장 다양한 타입, 유성/웜기어 | 불안정, 언더컷 미흡 |
| `py_gearworks` | build123d | 정밀 메싱, 프로필시프트, 사이클로이드 | 웜기어 미지원 |
| `bd_warehouse` | build123d | ISO 명세, 간결한 API | 스퍼기어만 지원 |
| `pygear` | pythonOCC | 호빙 시뮬레이션, STEP/IGES 출력 | 진입장벽 높음 |

---

## 결론

### 용도별 권고

| 시나리오 | 권고 도구 |
|---------|----------|
| 3D 프린팅/프로토타입 | **cq_gears** |
| build123d 워크플로우 통합 | **py_gearworks** |
| 간단한 스퍼기어 + build123d | **bd_warehouse** |
| 제조 시뮬레이션/연구 | **pygear** |
| 산업용 정밀 기어 (AGMA Q8+) | **KISSsoft / Romax** |

**핵심 판단**: 3D 프린팅, 시뮬레이션, 파라메트릭 자동화 목적에는 cq_gears로 충분. 수식 기반 인볼류트로 기능적으로 올바른 치형 생성. 산업용 동력 전달 정밀 기어는 전용 소프트웨어 필요.

---

## 근거 출처
- [cq_gears GitHub](https://github.com/meadiode/cq_gears)
- [py_gearworks GitHub](https://github.com/GarryBGoode/py_gearworks)
- [bd_warehouse gear documentation](https://bd-warehouse.readthedocs.io/en/latest/gear.html)
- [cadquery-contrib Involute_Gear.py](https://github.com/CadQuery/cadquery-contrib/blob/master/examples/Involute_Gear.py)
- [SplineCloud: Parametric Gear Models with CadQuery](https://splinecloud.com/blog/creating-parametric-gear-models-with-streamlit-and-cadquery/)
