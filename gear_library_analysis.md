# 기어 라이브러리 소스코드 분석 결과

> 분석일: 2026-03-13
> 분석 대상: cq_gears v0.62, py_gearworks (main branch)
> 분석 방법: 소스코드 직접 열람 (WebFetch)

---

## 요약: 한계의 근본 원인

| 한계 | cq_gears | py_gearworks |
|---|---|---|
| 언더컷 처리 | **없음** — 소치수 기어에서 형상 오류 발생 | **있음** — `InvoluteUndercutTooth` 클래스로 처리 |
| 프로파일 시프트 | **없음** | **있음** — `calc_nominal_mesh_distance` 등에서 지원 |
| 정밀 백래시 제어 | 치형 두께 감소(단순 근사)로 처리 | 선압력 방향 거리로 정확히 계산 |
| 중심거리 정밀 계산 | `r0_1 + r0_2` 단순 합산 | scipy.optimize.root로 압력각 변화 고려 |
| CAD 백엔드 | CadQuery (OCCT) | **build123d** (OCCT) — cq_gears와 다른 생태계 |
| 인볼류트 근사 정밀도 | **20 포인트 B-스플라인 근사** | **해석적 커브 객체** (연속 함수) |
| 기어 종류 | 스퍼/헬리컬/허링본/베벨/웜/랙/유성/교차헬리컬 | 스퍼/헬리컬/베벨/사이클로이드/인터널링 |
| 타입 힌트 | 거의 없음 | 전면 사용 |
| 테스트 | 없음 | 있음 (`tests/` 디렉토리) |

**핵심 결론**: cq_gears는 "충분히 동작하는 시각적 기어 생성기"이고, py_gearworks는 "정밀 기어 공학 라이브러리"다. 두 라이브러리 모두 CadQuery 기반 신규 라이브러리 구축에 직접 재사용하기 어려운 구조적 한계를 가진다.

---

## cq_gears 소스코드 분석

### 인볼류트 구현 (실제 코드 인용)

**기본 파라미터 계산** (`spur_gear.py`, `SpurGear.__init__`):

```python
d0 = m * z                           # 피치원 지름
adn = self.ka / (z / d0)             # 이끝 높이 (ka=1.0)
ddn = self.kd / (z / d0)             # 이뿌리 높이 (kd=1.25)
da = d0 + 2.0 * adn                  # 이끝원 지름
dd = d0 - 2.0 * ddn - 2.0 * clearance  # 이뿌리원 지름
s0 = m * (np.pi / 2.0 - backlash * np.tan(a0))  # 피치원 위 치형 두께
inv_a0 = np.tan(a0) - a0             # 기초원 인볼류트 값
self.rb = rb = np.cos(a0) * d0 / 2.0 # 기초원 반지름
self.rr = rr = max(rb, rd)           # 치근 반지름 (기초원과 이뿌리원 중 큰 쪽)
```

**인볼류트 곡선 포인트 계산** (20점 근사):

```python
curve_points = 20  # GearBase 클래스에 하드코딩

r = np.linspace(rr, ra, self.curve_points)  # 20개 등간격 반지름
cos_a = r0 / r * np.cos(a0)
a = np.arccos(np.clip(cos_a, -1.0, 1.0))
inv_a = np.tan(a) - a                        # 인볼류트 함수
s = r * (s0 / d0 + inv_a0 - inv_a)
phi = s / r
self.t_lflank_pts = np.dstack((np.cos(phi) * r,
                               np.sin(phi) * r,
                               np.zeros(self.curve_points))).squeeze()
```

**치형 구성 4개 구간**:
1. `t_lflank_pts` — 좌측 인볼류트 플랭크 (20점)
2. `t_tip_pts` — 이끝 호 (20점, 이끝원 위)
3. `t_rflank_pts` — 우측 인볼류트 플랭크 (좌측 미러, 20점)
4. `t_root_pts` — 이뿌리 호 (`circle3d_by3points`로 3점 정의 후 20점 샘플링)

**3D 면 생성** (`_build_tooth_faces`):

```python
face = cq.Face.makeSplineApprox(face_pts,
                                tol=self.spline_approx_tol,   # 1e-2
                                minDeg=self.spline_approx_min_deg,  # 3
                                maxDeg=self.spline_approx_max_deg)  # 8
```

- 스퍼 기어: `surface_splines = 2` (상/하 단면 2개 스플라인)
- 헬리컬 기어: `surface_splines = 5` (비틀림각 비례로 증가)
- `cq.Face.makeSplineApprox` → OCCT `GeomAPI_PointsToBSplineSurface` 직접 사용

**근사 오차의 함의**: 20점 B-스플라인으로 근사하기 때문에 `spline_approx_tol=1e-2`(0.01mm)의 형상 오차가 존재한다. 정밀 기어에서는 문제가 될 수 있다.

---

### 언더컷 처리 현황

**결론: cq_gears에는 언더컷 처리 코드가 전혀 없다.**

소치수 기어(z < 17, 압력각 20°)에서 발생하는 상황:

```python
self.rr = rr = max(rb, rd)  # 치근 반지름을 기초원과 이뿌리원 중 큰 쪽으로 설정
```

이 코드가 언더컷의 유일한 "방어막"이다. `rr`을 `rb`로 설정함으로써 기초원 아래로 인볼류트 커브가 연장되지 않도록 막는다. 그러나 이는 이뿌리 호가 기초원에서 갑자기 시작되는 형상으로, 실제 언더컷 곡선(트로코이드)이 아닌 단순 원호다.

결과:
- 소치수 기어(z = 5~12)에서 이뿌리 형상이 실제 제조 형상과 다름
- 맞물림 간섭(interference) 검사 없음
- 프로파일 시프트 미지원으로 소치수 기어 설계 대안 없음

---

### 백래시 구현

```python
s0 = m * (np.pi / 2.0 - backlash * np.tan(a0))
```

백래시를 피치원 위 치형 두께(`s0`)에서 `backlash * tan(압력각)` 만큼 감소시키는 방식이다. 이는 **치형 두께 감소 방식**으로, 양쪽 플랭크를 대칭적으로 얇게 만든다.

**문제점**: 실제 백래시는 선압력(line of action) 방향 거리로 정의되어야 하지만, 여기서는 단순 치형 두께 감소 근사를 사용한다. 미량의 백래시에서는 허용 가능하지만 정밀 계산에는 부적합하다.

링기어는 반대로 두께 증가:
```python
s0 = m * (np.pi / 2.0 + backlash * np.tan(a0))  # ring_gear.py
```

---

### 어셈블리 및 기어 쌍 메싱

**cq_gears는 기어 쌍 메싱 계산 기능이 없다.** 유성기어셋(`PlanetaryGearset`)과 베벨기어 쌍(`BevelGearPair`)에서 위치 배치 코드가 있지만, 이는 단순 기하 배치일 뿐이다.

유성기어셋 궤도 반지름 계산:
```python
self.orbit_r = self.sun.r0 + self.planet.r0  # 단순 피치원 반지름 합산
```

베벨기어 쌍 원뿔각 계산:
```python
delta_gear = np.arctan(aa_sin / (pinion_teeth / gear_teeth + aa_cos))
delta_pinion = np.arctan(aa_sin / (gear_teeth / pinion_teeth + aa_cos))
```

피니언 위치 배치:
```python
loc *= cq.Location(cq.Vector(0.0, 0.0, self.gear.cone_h), ...)
loc *= cq.Location(cq.Vector((0.0, 0.0, -self.pinion.cone_h)))
```

중심거리 = `r0_1 + r0_2` (프로파일 시프트 미고려). 맞물림 각도 계산 없음 (치형 위상 정렬 수동).

---

### CadQuery API 활용 방식

**플러그인 구조** (`__init__.py`):

```python
def gear(self, gear_, *build_args, **build_kv_args):
    gear_body = gear_.build(*build_args, **build_kv_args)
    gears = self.eachpoint(lambda loc: gear_body.located(loc), True)
    return gears

cq.Workplane.gear = gear       # 몽키 패칭
cq.Workplane.addGear = addGear
```

**Solid 생성 흐름**:

```
포인트 계산 (numpy)
  → cq.Face.makeSplineApprox (OCCT B-스플라인 곡면)
  → 각 이(tooth)별 Face 회전 복사
  → cq.Wire.combine (상/하면 와이어)
  → cq.Face.makeFromWires (평면 닫힘면)
  → make_shell (BRepBuilderAPI_Sewing, 톨러런스 1e-2)
  → cq.Solid.makeSolid (닫힌 Shell → Solid)
```

**OCCT 직접 호출**:
- `make_shell`: `BRepBuilderAPI_Sewing` 직접 사용
- `cq.Face.makeSplineApprox`: OCCT `GeomAPI_PointsToBSplineSurface` 래핑
- 나머지는 CadQuery Workplane API 사용

**Shell Sewing 허용 오차 문제**: `shell_sewing_tol = 1e-2`(0.01mm)로 설정되어 있어, 대형 기어나 복잡한 헬리컬 기어에서 Shell 조립 실패(`BRep_API: command not done`)가 발생하는 근본 원인이다.

---

### 코드 품질

| 항목 | 평가 |
|---|---|
| 모듈 구조 | 기어 종류별 파일 분리, 합리적 |
| 타입 힌트 | **없음** (Python 3.x임에도) |
| 테스트 | **없음** |
| 문서화 | 클래스/함수 docstring 없음, 인라인 주석 있음 |
| 에러 처리 | 일부 ValueError/assert 있지만 불완전 |
| 의존성 | numpy, cadquery만 필요 (경량) |
| 버전 | v0.62 (2024년 기준 활발히 유지) |

---

## py_gearworks 비교 분석

### 인볼류트 구현

py_gearworks는 **해석적 커브 객체(Curve class)** 방식을 사용한다. cq_gears의 사전 계산된 20점 배열과 달리, 연속 함수로 커브를 표현한다.

```python
class InvoluteCurve:
    # r = base radius, t는 연속 파라미터
    # involute_circle(t, r, ...) 함수로 임의 파라미터에서 점 계산
    base_radius = r
```

스퍼 기어(cone_angle=0) 인볼류트 생성:
```python
involute_curve = crv.InvoluteCurve(
    r=self.pitch_radius * np.cos(alpha), angle=0, t0=0, t1=2
)
# 피치원과 교점 수치 해석
sol2 = crv.find_curve_intersect(involute_curve, pitch_circle, guess=[0.5, 0])
```

베벨 기어의 경우 **구면 인볼류트(Spherical Involute)**를 사용:
```python
class SphericalInvoluteCurve:
    # c_sphere = 1/R, 구면 곡률
    # center_sphere = sqrt(R² - r²) * OUT
```

---

### 언더컷 처리 현황

py_gearworks는 `InvoluteUndercutTooth` 클래스에서 언더컷을 **실제 트로코이드 근사 커브**로 처리한다:

```python
class InvoluteUndercutTooth(InvoluteTooth):
    def generate_tooth_curve(self) -> crv.CurveChain:
        tooth_curve = self.generate_involute_curve()
        if tooth_curve[1].base_radius < self.pitch_radius - self.ref_limits.h_d:
            return tooth_curve  # 언더컷 불필요

        undercut_ref_point = self.get_default_undercut_ref_point()
        undercut_curve = generate_undercut_curve(
            pitch_radius=self.pitch_radius,
            cone_angle=self.cone_angle,
            undercut_ref_point=undercut_ref_point,
        )
        return trim_involute_undercut(tooth_curve, undercut_curve)
```

언더컷 커브 생성:
```python
def generate_undercut_curve(pitch_radius, cone_angle, undercut_ref_point):
    # 기어 랙 치형을 창성 기준으로 트로코이드 역산
    undercut_curve = crv.InvoluteCurve(
        r=pitch_radius,
        angle=0,
        v_offs=undercut_ref_point - RIGHT * pitch_radius,
        t0=0, t1=-1,
    )
```

`get_default_undercut_ref_point`는 기어 랙 기준 프로파일(`generate_involute_rack_curve`)을 생성하고, 피치 각도 절반 위치의 이뿌리 교점을 계산한다 — 표준 창성 이론을 정확히 구현한 것.

---

### 백래시 구현

py_gearworks는 백래시를 **선압력 방향 거리**로 정확히 계산한다:

```python
def calc_involute_mesh_distance(r_base_1, r_base_2, angle_base_1, angle_base_2,
                                 pitch_angle_2, inside_ring=False, backlash=0.0):
    # 비선형 방정식을 scipy.optimize.root로 풀어 정확한 중심거리 산출
    sol = root(
        lambda a: a - np.tan(a) + (d1 - d2 + backlash / 2) / (r_base_1 + r_base_2),
        0.0,
    )
    Dist = (r_base_1 + r_base_2) / np.cos(sol.x[0])
```

이는 맞물림 각도(working pressure angle)가 변하는 비선형 문제를 수치 해석으로 풀기 때문에 프로파일 시프트 포함 정확한 백래시 제어가 가능하다.

---

### 어셈블리 메싱

py_gearworks는 `Gear.mesh_to()` 메서드로 자동 위상 정렬을 제공한다:

```python
def mesh_to(self, other: "Gear", target_dir=RIGHT):
    if self.cone.cone_angle != 0 or other.cone.cone_angle != 0:
        # 베벨기어: 구면 기하로 배치 계산
        v0 = calc_bevel_gear_placement_vector(...)
        self.transform.orientation = calc_mesh_orientation(...)
    else:
        # 평기어: 피치원 합산 중심거리
        distance = self.rp + other.rp
        v0 = target_dir * distance + other.transform.center

    self.transform.angle = calc_mesh_angle(
        self.transform, other.transform,
        self.pitch_angle, other.pitch_angle, ...
    )
```

`calc_mesh_angle`은 두 기어의 현재 회전 위상을 고려해 맞물림 각도를 자동 계산한다. 이는 애니메이션 및 정확한 어셈블리에 필수적인 기능이다.

---

### CAD 백엔드 차이

py_gearworks는 **build123d**를 사용하며, CadQuery와 동일한 OCCT 커널이지만 API가 다르다(`wrapper.py`에서 `build123d.Part` import). CadQuery 환경에서 py_gearworks를 직접 사용할 수 없다.

---

## 핵심 기술 차이점 비교표

| 항목 | cq_gears | py_gearworks |
|---|---|---|
| **인볼류트 표현** | 20점 사전계산 배열 | 해석적 연속 함수 객체 |
| **언더컷** | 없음 (단순 rr=max(rb,rd)) | 있음 (트로코이드 커브 정확 구현) |
| **프로파일 시프트** | 없음 | 있음 |
| **백래시 계산** | s0 두께 근사 감소 | 선압력 방향 정확 계산 (scipy.root) |
| **중심거리 계산** | r1+r2 단순 합산 | 맞물림 압력각 고려 비선형 해석 |
| **치형 위상 정렬** | 없음 | calc_mesh_angle 자동 계산 |
| **베벨 기어 이론** | 구면 인볼류트 (s_inv 함수) | 구면 인볼류트 + Octoid 선택 가능 |
| **사이클로이드** | 없음 | 있음 (CycloidTooth 클래스) |
| **필렛** | 없음 | tip/root fillet 지원 |
| **크라우닝** | 없음 | 있음 (FilletParam.tip_reduction) |
| **CAD 백엔드** | CadQuery | build123d |
| **타입 힌트** | 없음 | 전면 사용 |
| **테스트** | 없음 | 있음 (tests/) |
| **의존성** | numpy, cadquery | numpy, scipy, build123d |
| **API 복잡도** | 낮음 (직관적) | 높음 (Recipe/Transform 추상화) |

---

## 신규 라이브러리 구축 시 재사용 가능한 부분

### cq_gears에서 참고 가능한 것

1. **GearBase 클래스 설계 패턴**: `__init__`에서 기하 계산, `build()`에서 3D 생성 분리 구조
2. **헬리컬/허링본 상속 구조**: `HerringboneGear(SpurGear)` 최소 오버라이드로 파생
3. **유성기어셋 tooth 수 검증 로직**: `(sun + planet) % n_planets` 가능성 경고
4. **베벨기어 원뿔각 계산 공식**: `delta = arctan(sin(axis_angle) / (z2/z1 + cos(axis_angle)))`
5. **CadQuery Workplane 몽키패칭 방식**: `cq.Workplane.gear = gear` 패턴
6. **`make_shell` OCCT 직접 호출**: `BRepBuilderAPI_Sewing` 허용 오차 커스텀

### py_gearworks에서 참고 가능한 것

1. **언더컷 알고리즘**: 기어 랙 기준 프로파일 → 트로코이드 역산 → 인볼류트와 교점 trim
2. **백래시 정밀 계산**: `calc_involute_mesh_distance` 수식 (scipy 불필요, 직접 구현 가능)
3. **프로파일 시프트 중심거리**: `calc_nominal_mesh_distance` 공식
4. **GearTransform/ConicData 데이터 클래스**: 위치/방향/스케일을 통합하는 설계
5. **치형 위상 정렬**: `calc_mesh_angle` 알고리즘 (두 기어 회전 위상 계산)
6. **ZFunctionMixin**: 파라미터를 z 위치의 함수로 정의하는 패턴 (테이퍼 기어 등)
7. **CurveChain 패턴**: 여러 커브를 체인으로 연결하고 교점 trim하는 방식

---

## 처음부터 새로 구현해야 하는 부분

### CadQuery 통합 레이어

py_gearworks의 커브 시스템(`curve.py`)은 build123d 전용이다. CadQuery에서 동작하려면:

- `crv.CurveChain` → `cq.Wire` 변환 레이어
- `crv.ArcCurve` → `cq.Edge.makeCircle` 매핑
- `crv.InvoluteCurve` 점 샘플링 → `cq.Edge.makeSpline`

### 인볼류트 커브 엔진

cq_gears의 20점 근사는 정밀도 부족, py_gearworks의 커브 시스템은 build123d 의존. 신규 구현 시:

- `t` 파라미터 연속 함수로 인볼류트 정의: `x(t) = r(cos(t) + t*sin(t))`, `y(t) = r(sin(t) - t*cos(t))`
- 적응형 샘플링(곡률 기반) 또는 50점 이상 고정 샘플링으로 정밀도 향상
- CadQuery `Edge.makeSpline(pts, tangents=...)` 활용으로 접선 연속성 보장

### 언더컷 + 프로파일 시프트 통합 계산기

```python
# 신규 구현 필요 핵심 수식
z_min = 2 / (sin(alpha))^2          # 언더컷 발생 최소 이 수
x_min = (z_min - z) / z_min         # 필요 최소 프로파일 시프트
working_alpha = arccos(rb * 2 / center_dist)  # 맞물림 압력각
```

### 정밀 Shell 생성 전략

cq_gears의 `shell_sewing_tol=1e-2`는 대형 기어에서 불안정하다. 신규 구현 시:
- Face 생성 후 Wire 연속성 검증 로직 추가
- 허용 오차를 모듈(m) 크기에 비례하여 적응적으로 설정
- 또는 `cq.Solid.extrudeLinear`/`twistExtrude` 활용으로 Shell sewing 우회

### 접촉비(Contact Ratio) 계산

두 라이브러리 모두 접촉비 출력이 없거나 불완전하다. 정밀 설계 검증을 위해:

```python
epsilon_alpha = (sqrt(ra1^2 - rb1^2) + sqrt(ra2^2 - rb2^2) - a*sin(alpha_w)) / (pi * m * cos(alpha))
```

### 강도 계산 연결 인터페이스

py_gearworks는 명시적으로 강도 계산 제외를 표방하고, cq_gears도 없다. ISO 6336 / AGMA 2001 기반 강도 계산 인터페이스는 신규 구현 필요.

---

## 부록: cq_gears 핵심 파일 구조

```
cq_gears/
├── __init__.py          # 버전 0.62, Workplane 패칭
├── spur_gear.py         # GearBase, SpurGear, HerringboneGear
├── ring_gear.py         # RingGear, PlanetaryGearset
├── bevel_gear.py        # BevelGear, BevelGearPair
├── worm_gear.py         # Worm
├── rack_gear.py         # RackGear, HerringboneRackGear
├── crossed_helical_gear.py  # CrossedHelicalGear, HyperbolicGear
└── utils.py             # circle3d_by3points, rotation_matrix, make_shell, s_inv, s_arc
```

## 부록: py_gearworks 핵심 파일 구조

```
src/py_gearworks/
├── __init__.py
├── defs.py              # 상수 (PI, UP, DOWN, RIGHT 등)
├── base_classes.py      # GearToothParam, ConicData, GearTransform, ZFunctionMixin 등
├── curve.py             # InvoluteCurve, SphericalInvoluteCurve, CurveChain, ArcCurve 등
├── function_generators.py  # involute_sphere, involute_circle 등 수학 함수
├── gearteeth.py         # InvoluteTooth, InvoluteUndercutTooth, OctoidTooth, CycloidTooth
├── core.py              # Gear 클래스, generate_reference_profile, GearProfileRecipe
├── gearmath.py          # calc_involute_mesh_distance, calc_mesh_angle, calc_nominal_mesh_distance
├── conv_build123d.py    # build123d 변환 레이어
├── conv_spline.py       # 스플라인 변환
└── wrapper.py           # SpurGear, HelicalGear 등 사용자 API 클래스
```
