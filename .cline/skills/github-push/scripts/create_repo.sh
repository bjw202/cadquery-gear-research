#!/bin/zsh
# create_repo.sh
# 사용법: ./create_repo.sh <repo_name> <public|private> [description] [commit_message]
# GitHub 저장소를 새로 생성하고 현재 디렉토리를 푸시

GIT=/usr/bin/git
GH=gh

REPO_NAME="$1"
VISIBILITY="$2"         # public 또는 private
DESCRIPTION="${3:-}"
COMMIT_MSG="${4:-Initial commit}"

# ── 인수 검증 ────────────────────────────────────────────────────
if [ -z "$REPO_NAME" ] || [ -z "$VISIBILITY" ]; then
  echo "STATUS:MISSING_ARGS"
  echo "사용법: create_repo.sh <repo_name> <public|private> [description] [commit_message]"
  exit 1
fi

if [ "$VISIBILITY" != "public" ] && [ "$VISIBILITY" != "private" ]; then
  echo "STATUS:INVALID_VISIBILITY"
  echo "visibility는 'public' 또는 'private'이어야 합니다."
  exit 1
fi

# ── gh 인증 확인 ─────────────────────────────────────────────────
if ! $GH auth status > /dev/null 2>&1; then
  echo "STATUS:NO_GH_AUTH"
  echo "'gh auth login'을 먼저 실행하세요."
  exit 1
fi

GH_USER=$($GH api user --jq .login 2>/dev/null)

# ── git 초기화 (필요 시) ─────────────────────────────────────────
if ! $GIT rev-parse --git-dir > /dev/null 2>&1; then
  $GIT init
  echo "git 저장소를 초기화했습니다."
fi

# ── 이미 origin이 설정된 경우 중단 ──────────────────────────────
EXISTING_REMOTE=$($GIT remote get-url origin 2>/dev/null)
if [ -n "$EXISTING_REMOTE" ]; then
  echo "STATUS:REMOTE_EXISTS"
  echo "이미 origin이 설정되어 있습니다: $EXISTING_REMOTE"
  echo "HINT: github_push.sh를 사용하여 기존 저장소에 푸시하세요."
  exit 1
fi

# ── 스테이징 → 커밋 ─────────────────────────────────────────────
$GIT add .
$GIT commit -m "$COMMIT_MSG

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" 2>/dev/null || echo "(커밋할 변경사항 없음, 기존 커밋으로 진행)"

# ── GitHub 저장소 생성 + 푸시 ────────────────────────────────────
if [ -n "$DESCRIPTION" ]; then
  CREATE_RESULT=$($GH repo create "$REPO_NAME" "--$VISIBILITY" --description "$DESCRIPTION" --source=. --remote=origin --push 2>&1)
else
  CREATE_RESULT=$($GH repo create "$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin --push 2>&1)
fi
CREATE_EXIT=$?

if [ $CREATE_EXIT -eq 0 ]; then
  echo "STATUS:SUCCESS"
  echo "저장소 생성 및 푸시 완료: https://github.com/$GH_USER/$REPO_NAME"
else
  echo "STATUS:CREATE_FAILED"
  echo "$CREATE_RESULT"
  exit 1
fi
