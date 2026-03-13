# 기어 가공 공정 설계 이론 조사

> 조사일: 2026-03-13

## 요약

기어 가공 공정 설계는 기어 타입, 모듈, 재질, 정밀도 등급, 생산량 5개 변수 조합으로 결정된다. 호빙이 외부 기어 대량 생산의 표준. AGMA A5 이상은 반드시 연삭 공정 포함.

---

## 가공 방법 전체 분류

| 방법 | 적용 기어 | 모듈 범위 | 정밀도(AGMA) | 생산성 |
| --- | --- | --- | --- | --- |
| 호빙(Hobbing) | 외부 스퍼/헬리컬/웜 | 0.5\~20 | A6\~A10 | 매우 높음 |
| 셰이핑(Shaping) | 내부/외부 스퍼/헬리컬 | 0.5\~10 | A4\~A8 | 낮음 |
| 폼 밀링 | 소량, 대형 모듈 | 2\~100+ | A6\~A10 | 낮음 |
| 5축 CNC 인보밀링 | 특수 기어, 소량 | 0.8\~100 | A2\~A6 | 중간 |
| 파워 스카이빙 | 내부/외부 고속 | 0.5\~10 | A4\~A6 | 높음 |
| 브로칭 | 내부 기어 대량 | 소형 전용 | A6\~A8 | 최고 |
| 연삭(Grinding) | 경화 후 마감 | 1\~15 | A0\~A3 | 낮음 |
| 호닝(Honing) | 경화 기어 마감 | 1\~10 | A2\~A4 | 중간 |
| 쉐이빙(Shaving) | 연질 기어 마감 | 1\~8 | A3\~A7 | 중간 |

---

## 가공 방법 선택 Decision Tree

```
기어 타입?
├─ 내부 기어
│   ├─ 생산량 >10,000 → 브로칭
│   ├─ 경화 재질, 고정밀 → 파워 스카이빙
│   └─ 일반 → 셰이핑
└─ 외부 기어
    ├─ 모듈 >6, 소량 → 5축 CNC 인보밀링
    ├─ 생산량 <500 → 폼 밀링 or 셰이핑
    └─ 생산량 ≥500, 모듈 0.5~20 → 호빙 (표준)

정밀도 등급?
├─ AGMA A11 이하 → 호빙/셰이핑으로 완료
├─ AGMA A7~A10 → 호빙 + 쉐이빙 or 호닝
├─ AGMA A5~A6 → 호빙 + 열처리 + 연삭
└─ AGMA A2~A4 → 호빙 + 열처리 + 정밀 연삭 + 래핑/호닝
```

---

## 호브(Hob) 선정 기준

| 호브 등급 | 런아웃 TIR | 달성 AGMA | 용도 |
| --- | --- | --- | --- |
| AA 등급 | ≤10 µm | A4\~A6 | 정밀, 항공·자동차 |
| A 등급 | ≤15 µm | A6\~A8 | 고정밀 일반 |
| B 등급 | ≤25 µm | A8\~A10 | 범용 상업 |

코팅: TiN(기본), TiAlN(건식/합금강), AlCrN(건식 최적, +50% 수명)

---

## 가공 조건 (재질별 호빙 기준)

| 재질 | 절삭속도 Vc (m/min) | 이송 (mm/rev) | 냉각제 |
| --- | --- | --- | --- |
| S45C | 50\~80 (HSS) / 100\~150 (초경) | 황삭 0.2\~0.4 / 정삭 0.2\~0.3 | 절삭유 |
| SCM440 | 40\~60 (HSS) / 80\~120 (초경) | 황삭 0.2\~0.3 / 정삭 0.15\~0.25 | 절삭유 |
| SUS304 | 30\~50 (HSS) / 100\~135 (초경) | 0.15\~0.25 | 절삭유 대량 |
| Al6061 | 100\~200 (초경) | 황삭 0.3\~0.5 / 정삭 0.3\~0.4 | 건식 or 합성 |
| 황동 | 60\~100 (HSS) | 0.2\~0.4 | 건식 가능 |
| 플라스틱 | 20\~50 (HSS) | 0.1\~0.3 | 건식 (공기) |

---

## 표준 공정 배치 패턴

### 중정밀 강재 (AGMA A8\~A10)

```
블랭크 선삭 → 호빙(황삭) → 호빙(정삭) → 쉐이빙 → 검사
```

### 고정밀 경화 기어 (AGMA A5\~A6)

```
블랭크 선삭 → 호빙 → 쉐이빙(선택) → 열처리(침탄소입) → 교정연삭 → 기어연삭 → 호닝(선택) → CMM 검사
```

### 초정밀 (AGMA A2\~A4)

```
정밀 블랭크 선삭 → 호빙(AA 호브) → 쉐이빙 → 열처리(제어 분위기) → 정밀 연삭(CBN) → 래핑/호닝 → CMM 전수 검사
```

---

## AGMA/ISO/DIN 등급 대응

| AGMA (구) | AGMA (ISO) | ISO 1328 | DIN 3961 | 주요 공정 |
| --- | --- | --- | --- | --- |
| Q6\~Q7 | A9\~A11 | 8\~9 | 8\~9 | 호빙 B급 |
| Q8\~Q9 | A7\~A8 | 6\~7 | 6\~7 | 호빙 A급 + 쉐이빙 |
| Q10\~Q11 | A5\~A6 | 4\~5 | 4\~5 | 호빙 AA급 + 연삭 |
| Q12\~Q13 | A3\~A4 | 3\~4 | 3\~4 | 정밀 연삭 + 호닝 |
| Q14\~Q15 | A2 | 1\~2 | 1\~2 | 초정밀 연삭 + 래핑 |

**주의**: AGMA는 숫자 클수록 고정밀, ISO/DIN은 숫자 작을수록 고정밀.

---

## Python 공정 결정 코드 예시

```python
def plan_gear_process(gear_spec):
    process_sequence = ['blank_turning']

    # 치형 절삭 방법 결정
    if gear_spec['type'] == 'internal':
        if gear_spec['production_volume'] > 10000:
            process_sequence.append('broaching')
        else:
            process_sequence.append('gear_shaping')
    else:
        if gear_spec['production_volume'] >= 500:
            process_sequence.append('gear_hobbing')
        else:
            process_sequence.append('form_milling')

    # 열처리 전 마감
    agma_num = int(gear_spec['precision_agma'].replace('A', ''))
    if agma_num >= 7:
        process_sequence.append('gear_shaving')

    # 열처리
    if gear_spec.get('heat_treatment'):
        process_sequence.append(f"heat_treatment_{gear_spec['heat_treatment']}")
        process_sequence.append('correction_grinding_blank')

    # 열처리 후 마감
    if agma_num <= 6:
        process_sequence.append('gear_grinding')
    if agma_num <= 4:
        process_sequence.append('gear_honing_or_lapping')

    process_sequence.append('final_inspection')
    return process_sequence
```

---

## 근거 출처

- [Gear Manufacturing Methods Review (PMC/NCBI)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10706903/)
- [Gear Hobbing Parameters (Toman Machines)](https://www.tomanmachines.com/news/unveiling-the-machining-parameters-for-hobbing-machines-when-processing-gears-of-different-materials-302707.html)
- [Gear Quality Standards: AGMA/DIN/ISO (MAS Gear Tech)](https://masgeartech.com/2025/09/05/gear-quality-standards-explained-agma-din-iso-what-procurement-needs-to-know/)
- [Sandvik Coromant: Gear Manufacturing](https://www.sandvik.coromant.com/en-us/knowledge/milling/gear-manufacturing)