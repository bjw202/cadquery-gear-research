# 신규 기어 전문 라이브러리 설계 가능성 검토

> 조사일: 2026-03-13

## 결론 (요약)

**기술적으로 충분히 가능하며, 만들 가치가 있다.**

현재 Python 생태계에 "정밀 3D 형상 생성 + AGMA/ISO 강도 계산"을 동시에 지원하는 라이브러리가 없다. 이것이 핵심 공백 지대이자 차별화 포인트다.

- cq_gears: 형상 생성 O, 강도 계산 X, 정밀도 제한, 불안정
- py_gearworks: 형상 생성 O, 강도 계산 X (미래 계획), 언더컷 O
- python-gearbox: 형상 생성 X, AGMA/ISO 계산 O, 개발 중단

---

## 기술적 구현 가능성 분석

### 정밀 인볼류트 치형

cq_gears의 20포인트 스플라인 근사를 개선하는 두 가지 방법:

**방법 A (권장): Bézier 다항식 분할 근사**

- FreeCAD gear workbench 방식: 차수 3-4 Bézier 곡선 2개로 치형 1개 표현
- OCCT `Geom2dAPI_Interpolate` + `.Load(startTangent, endTangent)`로 C1 연속성 보장
- 포인트 수 증가(50-100개)보다 수학적으로 더 정확한 접근

**방법 B: 해석적 인볼류트 직접 생성**

- OCCT는 해석적 원뿔곡선만 네이티브 지원. 인볼류트(초월함수)는 불가
- 결론: 근사가 불가피하나, Bézier 방식으로 충분히 정밀

### 언더컷 자동 처리 (구현 쉬움)

```python
# 언더컷 발생 조건 (20° 압력각 기준: 잇수 < 17)
z_min = 2 / (sin(α) ** 2)   # α = 압력각
x_min = (z_min - z) / z_min  # 최소 프로파일 시프트 계수
```

### 강도 계산

| 종류 | 공식 | 난이도 |
| --- | --- | --- |
| Lewis 굽힘 응력 | `σ = (Wt × Pd) / (F × Y)` | 쉬움 (3-5일) |
| AGMA 접촉 응력 | 수십 개 보정계수 포함 | 매우 어려움 (4-8주) |
| ISO 6336 | AGMA 유사, 계수 정의 다름 | 매우 어려움 |

### 물림률, 중심거리 계산

모두 해석적 공식 존재. Python으로 구현 가능 (각 2-5일).

---

## cq_gears 포크 vs 새로 작성

**새로 작성 권고.**

치형 알고리즘 교체가 핵심 작업인데, cq_gears에서 이는 가장 깊은 부분이다. 포크 시 레거시 구조를 유지하면서 핵심을 교체하는 것이 오히려 더 복잡하다.

---

## CadQuery vs build123d 기반 선택

**build123d 기반 권고.**

| 항목 | CadQuery 2.7 | build123d 0.10 |
| --- | --- | --- |
| 최신 릴리스 | 2026-02-13 | 2025-11-05 |
| OCCT 직접 접근 | 중간 | 높음 (OCP 직접 접근) |
| 기어 레퍼런스 | cq_gears (정체) | py_gearworks (활발, v0.0.18) |
| 장기 생태계 모멘텀 | 안정적 | 더 활발 |

---

## MVP 기능 정의 (v1.0)

### Must Have

1. 정밀 인볼류트 치형 (Bézier 기반)
2. 스퍼 기어, 헬리컬 기어, 링 기어(내접), 기어 랙
3. 언더컷 자동 감지 + 최소 프로파일 시프트 자동 계산
4. 물림률(contact ratio) 계산 및 경고
5. 기어 쌍 자동 중심거리 계산 (프로파일 시프트 포함)
6. Lewis 굽힘 응력 계산
7. CadQuery 2.x 또는 build123d 안정 버전 동작 보장

### v2.0 이후

- AGMA 2001 / ISO 6336 완전 구현
- 베벨 기어 (기하 복잡도 높음)
- 웜 기어 (자기교차 방지 알고리즘 필요)
- 유성 기어 어셈블리 자동화
- FEA 연동

---

## 구현 난이도 및 공수 추정

| 기능 | 난이도 | 추정 공수 |
| --- | --- | --- |
| Bézier 기반 정밀 인볼류트 치형 | 중간 | 2-3주 |
| 언더컷 자동 감지 + 최소 시프트 | 쉬움 | 3-5일 |
| 프로파일 시프트 최적화 | 중간 | 1-2주 |
| 물림률 계산 | 쉬움 | 2-3일 |
| 기어 쌍 중심거리 자동 계산 | 중간 | 3-5일 |
| Lewis 굽힘 응력 | 쉬움 | 3-5일 |
| AGMA 2001 완전 구현 | 매우 어려움 | 4-8주 |
| 베벨 기어 | 어려움 | 3-5주 |
| 웜 기어 | 매우 어려움 | 4-6주 |
| **MVP 전체** | **중간** | **6-10주 (1인 풀타임)** |

---

## 근거 출처

- [cq_gears GitHub](https://github.com/meadiode/cq_gears)
- [freecad.gears GitHub](https://github.com/looooo/freecad.gears)
- [FreeCAD involute.py](https://github.com/FreeCAD/FreeCAD/blob/main/src/Mod/PartDesign/fcgear/involute.py)
- [python-gearbox (AGMA/ISO)](https://github.com/efirvida/python-gearbox)
- [py_gearworks](https://github.com/GarryBGoode/py_gearworks)
- [OCCT Modeling Algorithms](https://dev.opencascade.org/doc/overview/html/occt_user_guides__modeling_algos.html)
- [Undercut of gears - tec-science](https://www.tec-science.com/mechanical-power-transmission/involute-gear/undercut/)