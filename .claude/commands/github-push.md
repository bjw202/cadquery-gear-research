# GitHub Push

현재 프로젝트를 GitHub에 푸시한다.
- 원격 저장소(origin)가 **있으면** → 커밋 메시지만 묻고 바로 푸시
- 원격 저장소(origin)가 **없으면** → 저장소 이름/공개 범위/설명을 물어보고 생성 후 푸시

## 실행 규칙

- git 명령은 반드시 `/usr/bin/git` 절대 경로를 사용한다
- gh 명령은 `gh` 그대로 사용한다 (PATH에 존재)
- `push --force`는 절대 사용하지 않는다
- `.env`, `*secret*`, `*credential*` 파일이 스테이징 대상에 포함된 경우 사용자에게 경고하고 확인을 받는다

## Step 1: 상태 파악

다음을 순서대로 실행한다:

```bash
gh auth status
```
```bash
/usr/bin/git rev-parse --git-dir
```
```bash
/usr/bin/git remote get-url origin
```
```bash
/usr/bin/git status --porcelain
```

결과에 따라 아래 중 하나로 분기한다.

---

## 분기 A: origin이 없는 경우 (신규 저장소 생성)

사용자에게 순서대로 질문한다:

1. **저장소 이름** → 기본값: 현재 디렉토리 이름
2. **공개 범위** → `public` / `private` (기본값: private)
3. **저장소 설명** → 선택 입력, 없으면 생략
4. **커밋 메시지** → 기본값: `Initial commit`

답변 수집 후 실행:

```bash
# git 초기화 (필요한 경우에만)
/usr/bin/git init

# 스테이징 & 커밋
/usr/bin/git add .
/usr/bin/git commit -m "{커밋 메시지}"

# GitHub 저장소 생성 + 원격 연결 + 푸시 (한 번에)
gh repo create {저장소_이름} --{public|private} --description "{설명}" --source=. --remote=origin --push
```

설명이 없는 경우 `--description` 옵션은 생략한다.

---

## 분기 B: origin이 있는 경우 (기존 저장소에 푸시)

사용자에게 질문한다:

1. **커밋 메시지** → 기본값: `chore: update files`

변경사항이 있으면 실행:

```bash
/usr/bin/git add .
/usr/bin/git commit -m "{커밋 메시지}"
/usr/bin/git push -u origin HEAD
```

변경사항이 없으면 (`git status --porcelain` 출력이 비어있으면) 사용자에게 알리고 종료한다.

---

## 완료 보고

성공 시 다음 형식으로 보고한다:

```
✅ GitHub 푸시 완료
저장소: https://github.com/{user}/{repo}
브랜치: main
커밋: {커밋 메시지}
```

오류 발생 시 stderr 내용을 그대로 보여주고 원인을 설명한다.
