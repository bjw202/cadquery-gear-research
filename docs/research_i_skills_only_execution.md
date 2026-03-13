# Cline Skills만으로 CadQuery 실행 가능성 조사

> 조사일: 2026-03-13 | 제약: 외부 MCP 사용 불가

## 핵심 결론

**가능하다.** MCP 없이 Skills + `execute_command`만으로 전체 플로우 구현 가능.

- SKILL.md 자체는 지침 텍스트 (코드 실행 능력 없음)
- 그러나 SKILL.md 안에 "이 스크립트를 실행하라" 지침 → Cline이 내장 `execute_command`로 실행
- `scripts/` 폴더에 Python 스크립트 배치 → 스크립트 코드는 토큰에 안 들어가고 stdout만 컨텍스트에 주입

---

## Skills 구조 및 동작 메커니즘

### 디렉토리 구조

```
.cline/skills/cadquery-gear/
├── SKILL.md            # 지침 (필수)
├── docs/               # 참조 문서 (선택)
├── templates/          # 코드 템플릿 (선택)
└── scripts/            # 실행 스크립트 (선택) ← 핵심
```

### 점진적 로딩 (토큰 효율)

| 단계 | 내용 | 토큰 비용 |
| --- | --- | --- |
| 메타데이터 | name + description만 | \~100 토큰 |
| 지침 | SKILL.md 전체 | &lt; 5,000 토큰 |
| 리소스 | docs/, scripts/, templates/ | 필요 시 온디맨드 |

### .clinerules vs Skills

| 구분 | .clinerules | Skills |
| --- | --- | --- |
| 로드 시점 | 항상 활성 | 요청 매칭 시 온디맨드 |
| 토큰 비용 | 항상 소비 | 필요 시만 소비 |
| 실행 능력 | 없음 | scripts/를 통해 간접 실행 |

---

## 구현 예제 (MCP 없음)

### 1. SKILL.md

```yaml
---
name: cadquery-gear
description: CadQuery로 파라미터 기어를 생성하고 STEP/STL 파일을 내보낸다.
             사용자가 기어 생성, 3D 모델 출력, CAD 파일 변환을 요청할 때 사용한다.
---

# CadQuery 기어 생성 스킬

## 파라미터 수집
사용자에게 다음을 질문한다 (기본값 제공):
- 잇수 (teeth): 기본 20
- 모듈 (module): 기본 2.0 mm
- 두께 (thickness): 기본 10 mm

## 스크립트 실행
수집된 파라미터로 scripts/generate_gear.py를 실행한다:
`python .cline/skills/cadquery-gear/scripts/generate_gear.py --teeth {teeth} --module {module} --thickness {thickness} --output ./output`

오류 발생 시 stderr 메시지를 설명하고 수정한다.
```

### 2. scripts/generate_gear.py

```python
#!/usr/bin/env python3
import argparse, sys, os

def generate_gear(teeth, module, thickness, output_dir):
    try:
        import cadquery as cq
        from cq_gears import SpurGear
    except ImportError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    gear_obj = SpurGear(module=module, teeth_number=teeth, width=thickness)
    wp = cq.Workplane('XY').gear(gear_obj)

    os.makedirs(output_dir, exist_ok=True)
    step_path = os.path.join(output_dir, f"gear_t{teeth}_m{module}.step")
    stl_path  = os.path.join(output_dir, f"gear_t{teeth}_m{module}.stl")

    cq.exporters.export(wp, step_path)
    cq.exporters.export(wp, stl_path)
    print(f"SUCCESS: STEP={step_path}, STL={stl_path}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--teeth",     type=int,   default=20)
    p.add_argument("--module",    type=float, default=2.0)
    p.add_argument("--thickness", type=float, default=10.0)
    p.add_argument("--output",    default="./output")
    args = p.parse_args()
    generate_gear(args.teeth, args.module, args.thickness, args.output)
```

### 3. Workflow (.clinerules/workflows/create-gear.md)

```markdown
# /create-gear Workflow

### Step 1: 파라미터 수집
잇수, 모듈, 두께, 출력 디렉토리를 사용자에게 질문

### Step 2: 환경 확인
`python -c "import cadquery; print('OK:', cadquery.__version__)"`

### Step 3: 기어 스크립트 실행
`python .cline/skills/cadquery-gear/scripts/generate_gear.py --teeth {teeth} --module {module} --thickness {thickness} --output {output_dir}`

### Step 4: 결과 확인 및 보고
```

---

## Hooks 활용 (선택적 자동화)

PostToolUse Hook: `.cq.py` 파일 저장 시 CadQuery 자동 실행

- 파일 작성(`write_to_file`) → Hook 트리거 → `python gear.cq.py` 실행 → stdout을 `contextModification`으로 Cline에 주입

---

## 한계

| 항목 | 상태 |
| --- | --- |
| SKILL.md 자체 코드 실행 | ❌ 불가 (텍스트 지침) |
| execute_command로 Python 실행 | ✅ 가능 |
| 실행 결과 컨텍스트 반영 | ✅ stdout/stderr 대화로 돌아옴 |
| GUI 3D 뷰어 (CQ-editor) | ❌ 불가 (별도 OCP CAD Viewer 필요) |
| 자동 실행 (승인 없이) | ⚠️ `requires_approval: false` 설정 필요 |

## 중요 발견: stdio MCP는 로컬 프로세스

"외부 MCP"의 정의: SSE Transport(HTTP URL) = 외부 서버 **stdio Transport = 로컬 프로세스** → `python cadquery_mcp_server.py`처럼 로컬 실행은 기술적으로 외부 MCP가 아님. 단, execute_command 직접 사용이 더 단순하므로 stdio MCP는 오버엔지니어링 가능성 있음.

---

## 근거 출처

- [Cline Skills 공식 문서](https://docs.cline.bot/features/skills)
- [Cline Tools 가이드](https://docs.cline.bot/exploring-clines-tools/cline-tools-guide)
- [Cline Hooks 레퍼런스](https://docs.cline.bot/features/hooks/hook-reference)
- [Cline 3.48.0 릴리스 노트 (Skills 도입)](https://cline.ghost.io/cline-3-48-0-skills-and-websearch-make-cline-smarter/)
- [DeepWiki Cline Skills System](https://deepwiki.com/cline/cline/7.4-skills-system)