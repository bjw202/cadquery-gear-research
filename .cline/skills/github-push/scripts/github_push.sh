#!/bin/zsh
# github_push.sh
# 사용법: ./github_push.sh [commit_message]
# - 원격 저장소가 있으면: 스테이징 → 커밋 → 푸시
# - 원격 저장소가 없으면: 상태 출력 후 종료 (SKILL.md가 사용자에게 생성 여부 질문)

GIT=/usr/bin/git
GH=gh

COMMIT_MSG="${1:-chore: update files}"

# ── 1. git 초기화 여부 확인 ──────────────────────────────────────
if ! $GIT rev-parse --git-dir > /dev/null 2>&1; then
  echo "STATUS:NO_GIT"
  echo "현재 디렉토리에 git 저장소가 없습니다."
  echo "HINT: git init 후 다시 실행하세요."
  exit 1
fi

# ── 2. gh 인증 확인 ─────────────────────────────────────────────
if ! $GH auth status > /dev/null 2>&1; then
  echo "STATUS:NO_GH_AUTH"
  echo "GitHub CLI 인증이 필요합니다. 'gh auth login'을 실행하세요."
  exit 1
fi

GH_USER=$($GH api user --jq .login 2>/dev/null)

# ── 3. 원격 저장소 존재 여부 확인 ────────────────────────────────
REMOTE_URL=$($GIT remote get-url origin 2>/dev/null)

if [ -z "$REMOTE_URL" ]; then
  echo "STATUS:NO_REMOTE"
  echo "원격 저장소(origin)가 설정되어 있지 않습니다."
  echo "GH_USER:$GH_USER"
  exit 2
fi

# ── 4. 변경사항 확인 ─────────────────────────────────────────────
CHANGED=$($GIT status --porcelain)

if [ -z "$CHANGED" ]; then
  echo "STATUS:NOTHING_TO_COMMIT"
  echo "변경사항이 없습니다. 푸시할 내용이 없습니다."
  exit 0
fi

# ── 5. 스테이징 → 커밋 → 푸시 ───────────────────────────────────
$GIT add .
$GIT commit -m "$COMMIT_MSG

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

PUSH_RESULT=$($GIT push -u origin HEAD 2>&1)
PUSH_EXIT=$?

if [ $PUSH_EXIT -eq 0 ]; then
  echo "STATUS:SUCCESS"
  echo "푸시 완료: $REMOTE_URL"
  echo "$PUSH_RESULT"
else
  echo "STATUS:PUSH_FAILED"
  echo "$PUSH_RESULT"
  exit 1
fi
