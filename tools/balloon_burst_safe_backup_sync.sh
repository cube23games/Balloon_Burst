#!/usr/bin/env bash
# Balloon Burst safe, idempotent disaster-recovery checkpoint.
# Never uses git push --mirror, --force, --prune, or deletes any remote ref.
# Matches the established ScratchLess private-backup workflow.
(
  set -Eeuo pipefail
  umask 077
  printf '\033[1;31m=== BALLOON BURST — COPY START ===\033[0m\n'
  done_ok=0
  on_exit() {
    rc=$?
    if [[ "$rc" -eq 0 && "$done_ok" -eq 1 ]]; then
      printf '\033[1;32m=== BALLOON BURST — COPY END ===\033[0m\n'
    else
      printf '\033[1;31m=== BALLOON BURST — STOPPED / COPY END ===\033[0m\n'
    fi
  }
  trap on_exit EXIT

  SRC="cube23games/Balloon_Burst"
  DEST="cube23games/Balloon_Burst-backup"
  CHECKPOINT="tj44f-spiraling-device-verified"
  ACCEPTED_SHA="787b13dc35da2dc40c21ba81a18773bfd4c8a0a6"
  ACCEPTED_RUN="42568021366"
  GITDIR="$HOME/repo-backups/balloon-burst-safe-sync.git"
  SRCPATH="https://github.com/$SRC.git"
  DESTPATH="https://github.com/$DEST.git"

  echo "TASK: TJ-44F — annotated checkpoint and private recovery mirror"
  echo "SOURCE: $SRC"
  echo "BACKUP: $DEST (PRIVATE)"
  echo "LOCAL BARE REPOSITORY: $GITDIR"

  command -v gh >/dev/null || { echo "STOP: install gh first"; exit 1; }
  command -v git >/dev/null || { echo "STOP: install git first"; exit 1; }
  command -v diff >/dev/null || { echo "STOP: install diffutils first"; exit 1; }

  # Use the saved cube23games GitHub CLI login, not an injected token or
  # a different account. This change is local to this subshell.
  unset GH_TOKEN GITHUB_TOKEN
  gh auth switch --hostname github.com --user cube23games >/dev/null
  ACTIVE="$(gh api user --jq '.login')"
  if [[ "$ACTIVE" != "cube23games" ]]; then
    echo "STOP: active GitHub account is not cube23games"
    exit 1
  fi
  echo "PASS: authenticated as cube23games"

  if [[ "$(gh api "repos/$SRC" --jq '.permissions.push')" != "true" ]]; then
    echo "STOP: cube23games lacks source repository push permissions"
    exit 1
  fi
  CHECK_RUN="$(gh api "repos/$SRC/actions/runs/$ACCEPTED_RUN" --jq '.head_sha + " " + .conclusion')"
  if [[ "$CHECK_RUN" != "$ACCEPTED_SHA success" ]]; then
    echo "STOP: accepted device QA checkpoint no longer matches the green CI evidence"
    echo "CI metadata: $CHECK_RUN"
    exit 1
  fi
  echo "PASS: signed CI run #75 succeeded for accepted commit $ACCEPTED_SHA"

  echo
  echo "=== CREATE OR VERIFY PRIVATE BACKUP REPOSITORY ==="
  if gh api "repos/$DEST" --jq '.id' >/dev/null 2>&1; then
    echo "Existing backup repository found; preserving its history."
  else
    echo "Creating PRIVATE recovery repository..."
    gh api --method POST user/repos \
      -f name=Balloon_Burst-backup \
      -f description='Private disaster-recovery mirror of Cube23 Balloon Burst' \
      -F private=true \
      -F auto_init=false \
      --jq '.full_name'
  fi
  if [[ "$(gh api "repos/$DEST" --jq '.private')" != "true" ]]; then
    echo "STOP: backup repository is NOT PRIVATE; refusing to transfer refs"
    exit 1
  fi
  if [[ "$(gh api "repos/$DEST" --jq '.permissions.push')" != "true" ]]; then
    echo "STOP: account lacks backup repository push permissions"
    exit 1
  fi
  echo "PASS: backup is PRIVATE and writable"

  echo
  echo "=== PREPARE ISOLATED BARE SYNCHRONIZATION REPOSITORY ==="
  mkdir -p "$HOME/repo-backups"
  if [[ -e "$GITDIR" ]]; then
    if [[ "$(git -C "$GITDIR" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]]; then
      echo "STOP: existing sync path is not a bare Git repository"
      exit 1
    fi
  else
    git init --bare --quiet "$GITDIR"
  fi

  set_remote() {
    name="$1"
    expected="$2"
    if existing="$(git -C "$GITDIR" remote get-url "$name" 2>/dev/null)"; then
      if [[ "$existing" != "$expected" ]]; then
        echo "STOP: $name remote points somewhere unexpected"
        exit 1
      fi
    else
      git -C "$GITDIR" remote add "$name" "$expected"
    fi
  }
  set_remote origin "$SRCPATH"
  set_remote backup "$DESTPATH"
  gh auth setup-git --hostname github.com
  echo "Fetching ALL source branches/tags into dedicated bare repository..."
  git -C "$GITDIR" fetch --no-tags origin \
    '+refs/heads/*:refs/heads/*' \
    '+refs/tags/*:refs/tags/*'
  git -C "$GITDIR" cat-file -e "$ACCEPTED_SHA^{commit}"

  echo
  echo "=== CREATE OR VERIFY IMMUTABLE ANNOTATED TJ-44F TAG ==="
  if git -C "$GITDIR" show-ref --verify --quiet "refs/tags/$CHECKPOINT"; then
    TAG_KIND="$(git -C "$GITDIR" cat-file -t "refs/tags/$CHECKPOINT")"
    TAG_TARGET="$(git -C "$GITDIR" rev-parse "refs/tags/$CHECKPOINT^{commit}")"
    if [[ "$TAG_KIND" != "tag" || "$TAG_TARGET" != "$ACCEPTED_SHA" ]]; then
      echo "STOP: an existing checkpoint tag is not the expected annotated tag"
      exit 1
    fi
    echo "PASS: existing annotated checkpoint points to accepted source"
  else
    AUTHOR_ID="$(gh api user --jq '.id')"
    git -C "$GITDIR" \
      -c user.name='Cube23 Games' \
      -c user.email="$AUTHOR_ID+cube23games@users.noreply.github.com" \
      tag -a "$CHECKPOINT" "$ACCEPTED_SHA" \
      -m 'TJ-44F Spiraling Skies: six playable levels, signed CI #75 green and Moto G device QA accepted; development checkpoint, not Play release'
    echo "Created annotated tag locally: $CHECKPOINT"
  fi
  # Push the checkpoint to the source repo FIRST, without force.
  git -C "$GITDIR" push origin "refs/tags/$CHECKPOINT:refs/tags/$CHECKPOINT"
  echo "PASS: source repository has the checkpoint tag"

  echo
  echo "=== NON-DESTRUCTIVE BACKUP SYNC ==="
  # Seed main first, so a new empty backup is initialized on main even
  # though the primary's configured default is accuracy-expose-v1.
  git -C "$GITDIR" push backup 'refs/heads/main:refs/heads/main'
  git -C "$GITDIR" push backup 'refs/heads/*:refs/heads/*'
  git -C "$GITDIR" push backup 'refs/tags/*:refs/tags/*'

  BACKUP_DEFAULT="$(gh api "repos/$DEST" --jq '.default_branch')"
  if [[ "$BACKUP_DEFAULT" != "main" ]]; then
    gh api --method PATCH "repos/$DEST" -f default_branch=main --jq '.default_branch'
  fi
  if [[ "$(gh api "repos/$DEST" --jq '.default_branch')" != "main" ]]; then
    echo "STOP: backup default branch is not main"
    exit 1
  fi

  echo
  echo "=== VERIFY ALL REMOTE REFS EXACTLY ==="
  COMPARE_DIR="$(mktemp -d "$HOME/repo-backups/balloon-verify.XXXXXXXX")"
  trap 'rm -rf "$COMPARE_DIR"; on_exit' EXIT
  git -C "$GITDIR" ls-remote --heads --tags origin | LC_ALL=C sort > "$COMPARE_DIR/source.refs"
  git -C "$GITDIR" ls-remote --heads --tags backup | LC_ALL=C sort > "$COMPARE_DIR/backup.refs"
  if ! diff -u "$COMPARE_DIR/source.refs" "$COMPARE_DIR/backup.refs"; then
    echo "STOP: some backup refs or commit IDs differ from the source"
    exit 1
  fi
  NUM_BRANCHES="$(awk -F '\t' '$2 ~ /^refs\/heads\// {n++} END {print n+0}' "$COMPARE_DIR/source.refs")"
  NUM_TAGS="$(awk -F '\t' '$2 ~ /^refs\/tags\// && $2 !~ /\^\{\}$/ {n++} END {print n+0}' "$COMPARE_DIR/source.refs")"
  if (( NUM_BRANCHES < 13 || NUM_TAGS < 130 )); then
    echo "STOP: unexpectedly low reference counts: $NUM_BRANCHES branches, $NUM_TAGS tags"
    exit 1
  fi
  # Annotated tag must peel to the exact QA-verified commit at BOTH remotes.
  for remote in origin backup; do
    PEELED="$(git -C "$GITDIR" ls-remote --tags "$remote" "refs/tags/$CHECKPOINT^{}" | awk '{print $1}')"
    if [[ "$PEELED" != "$ACCEPTED_SHA" ]]; then
      echo "STOP: $remote checkpoint tag target does not match signed CI #75"
      exit 1
    fi
  done
  RECEIPT="$HOME/repo-backups/BALLOON_BURST_BACKUP_VERIFY_$(date +%Y%m%d_%H%M%S).txt"
  {
    echo "PROJECT: cube23games/Balloon_Burst"
    echo "PRIVATE_BACKUP: cube23games/Balloon_Burst-backup"
    echo "ACCEPTED_COMMIT: $ACCEPTED_SHA"
    echo "SIGNED_CI_RUN: $ACCEPTED_RUN"
    echo "ANNOTATED_TAG: $CHECKPOINT"
    echo "BRANCH_REFS_VERIFIED: $NUM_BRANCHES"
    echo "TAG_REFS_VERIFIED: $NUM_TAGS"
    echo "BACKUP_DEFAULT_BRANCH: main"
    echo "VERIFICATION: all refs/heads and refs/tags match exactly"
    sha256sum "$COMPARE_DIR/source.refs" "$COMPARE_DIR/backup.refs"
  } > "$RECEIPT"
  echo "PASS: $NUM_BRANCHES branches and $NUM_TAGS tags match byte-for-byte."
  echo "PASS: both checkpoint tags peel to $ACCEPTED_SHA"
  echo "PASS: backup is PRIVATE and its default branch is main"
  echo "RECEIPT: $RECEIPT"
  echo "No force-push, pruning, deletions, or source main changes performed."
  done_ok=1
)
