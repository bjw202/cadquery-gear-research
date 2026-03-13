# 기어 라이브러리 소스코드 심층 분석

> 조사일: 2026-03-13 | 대상: cq_gears, py_gearworks 소스코드 직접 분석

## 요약: 한계의 근본 원인

두 라이브러리는 설계 철학이 근본적으로 다르다.

- **cq_gears**: "시각적으로 충분히 동작하는 기어 생성기" — 빠르고 단순하지만 공학적 정밀도 부족
- **py_gearworks**: "정밀 기어 공학 라이브러리" — 정확하지만 build123d 전용으로 CadQuery에서 직접 재사용 불가

---

## cq_gears 소스코드 분석

### 인볼류트 구현 (실제 코드)

`GearBase` 클래스에 `curve_points = 20`이 하드코딩. 20개 이산점으로 인볼류트 곡선 사전계산 후 `cq.Face.makeSplineApprox(tol=1e-2)`로 B-스플라인 곡면 생성.
**허용 오차 0.01mm의 근사 오차가 구조적으로 내재.**

```python
# GearBase 클래스 핵심 (cq_gears/spur_gear.py)
curve_points = 20  # 하드코딩

d0 = m * z
rb = np.cos(a0) * d0 / 2.0   # 기초원
ra = d0/2 + adn               # 이끝원
rd = d0/2 - ddn - clearance   # 이뿌리원
rr = max(rb, rd)              # 치근 반지름 (기초원과 이뿌리원 중 큰 쪽)
```

### 언더컷 처리

**전혀 없음.** `rr = max(rb, rd)` 한 줄이 유일한 방어막. 기초원 아래 인볼류트 연장 차단만 할 뿐, 실제 트로코이드 언더컷 곡선 없음. 맞물림 간섭 검사 없음. 프로파일 시프트 미지원.

### 백래시 구현

`s0 = m * (π/2 - backlash * tan(α))` — 피치원 위 치형 두께 감소 방식. 선압력 방향 정확한 계산이 아닌 단순 근사.

### 어셈블리 메싱

중심거리 = `r0_1 + r0_2` 단순 합산 (프로파일 시프트 미고려). 맞물림 각도 자동 계산 없음 — 치형 위상 정렬을 사용자가 수동 처리.

### CadQuery API 활용 방식

- `cq.Workplane.gear = gear` 몽키패칭으로 플러그인 구조 구현
- Shell 생성 시 `BRepBuilderAPI_Sewing(tol=1e-2)` OCCT 직접 호출
- **이 허용 오차가 대형/복잡 기어에서 "command not done" 오류의 근본 원인**

### 코드 품질

타입 힌트 없음, 테스트 없음, docstring 없음. 인라인 주석만 있음.

---

## py_gearworks 비교 분석

| 항목 | cq_gears | py_gearworks |
|------|----------|-------------|
| 인볼류트 표현 | 20점 이산 배열 | 해석적 연속 함수 객체 (`InvoluteCurve`) |
| 교점 계산 | 없음 | scipy 기반 정확 계산 |
| 언더컷 | 없음 | `InvoluteUndercutTooth` 클래스, 트로코이드 역산 |
| 백래시 | 단순 두께 감소 | `scipy.optimize.root`로 비선형 방정식 정확 풀이 |
| 메싱 | 단순 중심거리 합산 | `Gear.mesh_to()` 위치·방향·위상 자동 계산 |
| 프로파일 시프트 | 미지원 | 지원 |
| CAD 백엔드 | CadQuery | **build123d 전용 (CadQuery 호환 불가)** |
| 타입 힌트 | 없음 | 있음 |

---

## 신규 라이브러리 구축 관점

### cq_gears에서 재사용 가능한 구조 패턴
- `GearBase`의 init/build 분리 패턴
- 헬리컬/헤링본 상속 구조
- 베벨기어 원뿔각 공식
- Workplane 몽키패칭 방식

### py_gearworks에서 알고리즘 참고 가능
- 언더컷 알고리즘 (트로코이드 역산 방식)
- `calc_involute_mesh_distance` 백래시 수식 (scipy 없이도 직접 구현 가능)
- `calc_mesh_angle` 치형 위상 정렬 알고리즘
- ZFunctionMixin 패턴 (가변 파라미터 대응)

### 처음부터 구현해야 하는 것
1. CadQuery용 인볼류트 커브 엔진 (50점 이상 또는 적응형 샘플링, 접선 연속성 포함)
2. 언더컷 + 프로파일 시프트 통합 계산기
3. 적응형 Shell sewing 허용 오차 (모듈 크기 비례)
4. 접촉비(Contact Ratio) 계산 출력
5. 강도 계산 연결 인터페이스 (ISO 6336 / AGMA)
