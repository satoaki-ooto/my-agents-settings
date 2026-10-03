#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Blocks `git push` that would update main/master.
# Exit 2 = block (stderr is shown to Claude). Exit 0 = allow.
#
# Why a hook on top of permissions: permission patterns match command strings only,
# so `git push origin HEAD` while on main, or `git push origin feat:main`, slip through.
# This script resolves the push destination instead.
#
# deliberate: tokenizes by whitespace, no full shell parsing. Variable expansion
# (`git push origin $BR`) and aliases are not resolved. Pair with GitHub branch
# protection for a hard guarantee.

set -f # no globbing while word-splitting below

block() {
  echo "BLOCKED: $1. git push to main/master is forbidden; push a feature branch instead." >&2
  exit 2
}

# Fail closed: a guard that silently stops guarding is worse than one that errors.
command -v jq >/dev/null || block "jq not found, cannot inspect command"

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

[[ $cmd == *push* ]] || exit 0

current_branch() { git -C "${cwd:-.}" symbolic-ref --short -q HEAD; }

is_protected() {
  case ${1#refs/heads/} in
    main | master) return 0 ;;
  esac
  return 1
}

check_refspec() {
  local dst=${1#+}
  dst=${dst##*:} # `src:dst` -> dst, `:dst` (delete) -> dst, `name` -> name
  case $dst in
    *'*'*) block "wildcard refspec '$1' may include main/master" ;;
    '' | HEAD) dst=$(current_branch) ;;
  esac
  ! is_protected "$dst" || block "push to '$dst' (refspec '$1')"
}

check_segment() {
  local -a words positional=()
  local w seen_git=0 seen_push=0
  read -ra words <<<"$1"
  for w in "${words[@]}"; do
    w=${w//[\"\']/} # strip quotes so `bash -c "git push ..."` is caught
    if ((!seen_push)); then
      [[ $w == git ]] && seen_git=1
      ((seen_git)) && [[ $w == push ]] && seen_push=1
      continue
    fi
    case $w in
      --all | --mirror) block "git push $w" ;;
      -*) ;;
      *) positional+=("$w") ;;
    esac
  done
  ((seen_push)) || return 0

  # positional[0] is the remote; the rest are refspecs. None given = current branch.
  if ((${#positional[@]} <= 1)); then
    check_refspec HEAD
    return
  fi
  local r
  for r in "${positional[@]:1}"; do check_refspec "$r"; done
}

# Split on shell separators so `cd x && git push origin main` is seen as its own segment.
while IFS= read -r segment; do
  check_segment "$segment"
done <<<"$(printf '%s' "$cmd" | tr ';&|()`' '\n\n\n\n\n\n')"

exit 0
