---
name: github-push
description: 현재 프로젝트를 GitHub에 푸시한다. 기존 저장소가 있으면 바로 푸시하고,
             없으면 저장소 이름과 공개 범위를 물어보고 생성 후 푸시한다.
             사용자가 "깃헙에 올려줘", "push해줘", "레포 만들어서 올려줘",
             "GitHub에 저장해줘" 등을 요청할 때 사용한다.
---

# GitHub Push 스킬

## 전제 조건

- `gh` CLI 설치 및 로그인 완료 (`gh auth status`로 확인)
- `/usr/bin/git` 사용 (PATH의 git 대신 절대 경로 사용)
- 스크립트 경로: `.cline/skills/github-push/scripts/`

---

## 실행 흐름

### Step 1: 상태 파악

다음 명령으로 현재 git/remote 상태를 확인한다:

```bash
/bin/chmod +x .cline/skills/github-push/scripts/github_push.sh
/bin/chmod +x .cline/skills/github-push/scripts/create_repo.sh
zsh .cline/skills/github-push/scripts/github_push.sh "임시 확인"
```

stdout의 `STATUS:` 값에 따라 분기한다:

| STATUS | 의미 | 다음 행동 |
|--------|------|-----------|
| `SUCCESS` | 푸시 성공 | 완료 보고 |
| `NOTHING_TO_COMMIT` | 변경사항 없음 | 사용자에게 알림 |
| `NO_REMOTE` | 원격 저장소 없음 | → Step 2A (신규 생성) |
| `NO_GIT` | git 초기화 안 됨 | `git init` 후 → Step 2A |
| `NO_GH_AUTH` | gh 인증 없음 | 사용자에게 `gh auth login` 안내 |

---

### Step 2A: 신규 저장소 생성 (STATUS가 NO_REMOTE인 경우)

사용자에게 다음을 질문한다:

1. **저장소 이름** (기본값: 현재 디렉토리 이름)
   - "저장소 이름을 알려주세요. (기본값: `{현재_디렉토리_이름}`)"
2. **공개 범위** (기본값: private)
   - "public으로 만들까요, private으로 만들까요? (기본값: private)"
3. **설명** (선택, 생략 가능)
   - "저장소 설명을 입력해주세요. (없으면 Enter)"
4. **커밋 메시지** (기본값: "Initial commit")
   - "첫 번째 커밋 메시지를 입력해주세요. (기본값: Initial commit)"

답변 수집 후 실행:

```bash
zsh .cline/skills/github-push/scripts/create_repo.sh \
  "{repo_name}" \
  "{public_or_private}" \
  "{description}" \
  "{commit_message}"
```

STATUS가 `SUCCESS`이면 완료 보고. `CREATE_FAILED`이면 오류 메시지를 사용자에게 그대로 전달.

---

### Step 2B: 기존 저장소에 푸시 (origin이 이미 설정된 경우)

사용자에게 커밋 메시지를 묻는다:

- "커밋 메시지를 입력해주세요. (기본값: chore: update files)"

```bash
zsh .cline/skills/github-push/scripts/github_push.sh "{commit_message}"
```

---

## 완료 보고 형식

```
✅ GitHub 푸시 완료
- 저장소: https://github.com/{user}/{repo}
- 브랜치: main
- 커밋: {commit_message}
```

---

## 주의사항

- `.env`, `*credentials*`, `*secret*` 등 민감 파일이 스테이징에 포함된 경우 사용자에게 경고하고 확인을 받는다.
- `.gitignore`가 없으면 생성할지 물어본다.
- `push --force`는 절대 사용하지 않는다.
