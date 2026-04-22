#!/bin/bash

set -euo pipefail

FORMULA_DIR="Formula"
DEBUG=0

usage() {
    cat <<'EOF'
用法:
  ./update_formulas.sh [formula ...]

行为:
  - 不传参数时，更新 Formula/*.rb 下的全部公式
  - 传入参数时，只更新指定公式
  - 写入前先比较当前 formula 里的 version、tag、revision
  - GitHub 仓库优先通过 Releases API 获取最新 tag
  - 再解析这个 tag 对应的 revision
  - 拿不到 release tag 时，才回退到远程 tag 列表
  - 传入 --debug 时，逐步打印调试日志

示例:
  ./update_formulas.sh
  ./update_formulas.sh gptcomet
  ./update_formulas.sh Formula/gh-download.rb
  ./update_formulas.sh trash-cli-rs
  ./update_formulas.sh --debug gptcomet

环境变量:
  REMOTE_URL    只更新一个公式时，覆盖默认远程 git 地址
  TAG_PATTERN   回退到远程 tag 列表时使用的模式，默认：v*
  GITHUB_TOKEN  GitHub API 可选令牌
  GH_TOKEN      GitHub API 可选令牌，作为回退
EOF
}

normalize_formula_name() {
    local input="$1"
    local name

    name="$(basename "$input")"
    name="${name%.rb}"
    printf '%s\n' "$name"
}

detect_remote_url() {
    local formula_file="$1"
    perl -ne '
        if (/^\s*url\s+"([^"]+)"/) {
            print "$1\n";
            exit 0;
        }
    ' "$formula_file"
}

detect_formula_value() {
    local formula_file="$1"
    local field="$2"

    case "$field" in
        version)
            perl -ne '
                if (/^\s*version\s+"([^"]+)"/) {
                    print "$1\n";
                    exit 0;
                }
            ' "$formula_file"
            ;;
        tag)
            perl -ne '
                if (/^\s*tag:\s+"([^"]+)"/) {
                    print "$1\n";
                    exit 0;
                }
            ' "$formula_file"
            ;;
        revision)
            perl -ne '
                if (/^\s*revision:\s+"([^"]+)"/) {
                    print "$1\n";
                    exit 0;
                }
            ' "$formula_file"
            ;;
        *)
            echo "错误：不支持的 formula 字段：$field" >&2
            return 1
            ;;
    esac
}

replace_formula_value() {
    local formula_file="$1"
    local pattern="$2"
    local replacement="$3"

    perl -0pi -e "s/$pattern/$replacement/" "$formula_file"
}

print_formula_header() {
    local formula_name="$1"
    local formula_file="$2"

    printf '\n==> %s\n' "$formula_name" >&2
    printf '    公式文件：%s\n' "$formula_file" >&2
}

print_group() {
    local title="$1"
    local version="$2"
    local tag="$3"
    local revision="$4"

    printf '    [%s]\n' "$title" >&2
    printf '      版本    ：%s\n' "$version" >&2
    printf '      标签    ：%s\n' "$tag" >&2
    printf '      修订    ：%s\n' "$revision" >&2
}

print_result() {
    local status="$1"
    local detail="$2"

    printf '    [结果]\n' >&2
    printf '      状态    ：%s\n' "$status" >&2
    printf '      说明    ：%s\n' "$detail" >&2
}

debug_start() {
    local action="$1"

    [ "${DEBUG:-0}" -eq 1 ] || return 0
    printf '    [调试] 正在%s……\n' "$action" >&2
}

debug_done() {
    local action="$1"
    local detail="$2"

    [ "${DEBUG:-0}" -eq 1 ] || return 0
    printf '    [调试] 成功%s：%s\n' "$action" "$detail" >&2
}

debug_fail() {
    local action="$1"
    local detail="$2"

    [ "${DEBUG:-0}" -eq 1 ] || return 0
    printf '    [调试] 失败%s：%s\n' "$action" "$detail" >&2
}

http_get() {
    local url="$1"
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

    if [ -n "$token" ]; then
        curl -fsSL \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $token" \
            "$url"
    else
        curl -fsSL \
            -H "Accept: application/vnd.github+json" \
            "$url"
    fi
}

git_ls_remote() {
    env \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_TERMINAL_PROMPT=0 \
        git ls-remote "$@"
}

github_repo_from_url() {
    local remote_url="$1"
    perl -e '
        my $url = shift @ARGV;
        if ($url =~ m{^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$}) {
            print "$1/$2\n";
            exit 0;
        }
        if ($url =~ m{^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$}) {
            print "$1/$2\n";
            exit 0;
        }
        exit 1;
    ' "$remote_url"
}

github_latest_release_tag() {
    local remote_url="$1"
    local repo api_url tag

    debug_start "识别 GitHub 仓库信息"
    repo="$(github_repo_from_url "$remote_url" 2>/dev/null || true)"
    if [ -z "$repo" ]; then
        debug_fail "识别 GitHub 仓库信息" "当前远程地址不是 GitHub 仓库"
        return 1
    fi
    debug_done "识别 GitHub 仓库信息" "仓库是 ${repo}"

    api_url="https://api.github.com/repos/${repo}/releases/latest"
    debug_start "通过 GitHub Releases API 获取最新发布标签"
    tag="$(http_get "$api_url" 2>/dev/null | perl -MJSON::PP -e '
        local $/;
        my $json = <STDIN>;
        my $data = eval { JSON::PP::decode_json($json) };
        exit 1 if !$data || ref($data) ne "HASH";
        exit 1 if !defined $data->{tag_name} || $data->{tag_name} eq "";
        print $data->{tag_name}, "\n";
    ' || true)"
    if [ -n "$tag" ]; then
        debug_done "通过 GitHub Releases API 获取最新发布标签" "标签是 ${tag}"
        printf '%s\n' "$tag"
        return 0
    fi

    debug_fail "通过 GitHub Releases API 获取最新发布标签" "没有拿到 latest release tag"
    return 1
}

latest_remote_tag() {
    local remote_url="$1"
    local latest_tag tag_pattern

    latest_tag="$(github_latest_release_tag "$remote_url" || true)"
    if [ -n "$latest_tag" ]; then
        printf '%s\n' "$latest_tag"
        return 0
    fi

    tag_pattern="${TAG_PATTERN:-v*}"
    debug_start "通过远程 tag 列表查找最新标签"
    latest_tag="$(git_ls_remote --tags --refs --sort=-version:refname "$remote_url" "$tag_pattern" | perl -ne '
        if (/\trefs\/tags\/([^\s]+)$/) {
            print "$1\n";
            exit 0;
        }
    ' || true)"
    if [ -n "$latest_tag" ]; then
        debug_done "通过远程 tag 列表查找最新标签" "模式 ${tag_pattern}，标签是 ${latest_tag}"
        printf '%s\n' "$latest_tag"
        return 0
    fi

    debug_fail "通过远程 tag 列表查找最新标签" "模式 ${tag_pattern}，没有找到匹配的标签"
    return 1
}

update_formula() {
    local formula_name="$1"
    local formula_file="$FORMULA_DIR/$formula_name.rb"
    local remote_url latest_tag version revision tag_refs
    local current_version current_tag current_revision

    if [ ! -f "$formula_file" ]; then
        echo "错误：找不到 formula 文件：$formula_file" >&2
        return 1
    fi

    if [ "${REMOTE_URL:-}" != "" ] && [ "${FORMULA_COUNT:-0}" -eq 1 ]; then
        remote_url="$REMOTE_URL"
    else
        remote_url="$(detect_remote_url "$formula_file")"
    fi

    if [ -z "$remote_url" ]; then
        echo "错误：无法从 $formula_file 识别远程地址" >&2
        return 1
    fi

    print_formula_header "$formula_name" "$formula_file"
    debug_start "解析远程地址"
    debug_done "解析远程地址" "地址是 ${remote_url}"

    debug_start "读取当前公式值"
    current_version="$(detect_formula_value "$formula_file" version || true)"
    current_tag="$(detect_formula_value "$formula_file" tag || true)"
    current_revision="$(detect_formula_value "$formula_file" revision || true)"
    debug_done "读取当前公式值" "版本=${current_version:-<缺失>}，标签=${current_tag:-<缺失>}，修订=${current_revision:-<缺失>}"

    latest_tag="$(latest_remote_tag "$remote_url")"
    if [ -z "$latest_tag" ]; then
        echo "错误：没有为 $formula_name 找到远程标签：$remote_url" >&2
        return 1
    fi

    version="${latest_tag#v}"
    debug_start "解析远程标签对应的修订"
    tag_refs="$(git_ls_remote --tags "$remote_url" "refs/tags/$latest_tag" "refs/tags/$latest_tag^{}")"
    revision="$(printf '%s\n' "$tag_refs" | awk -v tag="$latest_tag" '$2 == "refs/tags/" tag "^{}" { print $1; exit }')"
    if [ -z "$revision" ]; then
        revision="$(printf '%s\n' "$tag_refs" | awk -v tag="$latest_tag" '$2 == "refs/tags/" tag { print $1; exit }')"
    fi
    if [ -z "$revision" ]; then
        debug_fail "解析远程标签对应的修订" "标签 ${latest_tag} 没有对应的远程修订"
        echo "错误：无法从 $remote_url 解析 $latest_tag 对应的远程修订" >&2
        return 1
    fi
    debug_done "解析远程标签对应的修订" "标签 ${latest_tag} 的修订是 ${revision}"

    print_group "当前" "${current_version:-<缺失>}" "${current_tag:-<缺失>}" "${current_revision:-<缺失>}"
    print_group "远程" "$version" "$latest_tag" "$revision"

    debug_start "比较当前值和远程值"
    if [ "$current_version" = "$version" ] &&
        [ "$current_tag" = "$latest_tag" ] &&
        [ "$current_revision" = "$revision" ]; then
        debug_done "比较当前值和远程值" "两边一致，无需写入"
        print_result "未变更" "已经是最新版本"
        return 0
    fi
    debug_done "比较当前值和远程值" "检测到差异，需要写入"

    debug_start "写入公式文件"
    replace_formula_value "$formula_file" 'tag:\s+"[^"]*"' "tag:      \"$latest_tag\"" &&
        replace_formula_value "$formula_file" 'revision:\s+"[^"]*"' "revision: \"$revision\"" &&
        replace_formula_value "$formula_file" 'version\s+"[^"]*"' "version \"$version\""
    debug_done "写入公式文件" "已同步到 ${latest_tag}"

    print_result "已更新" "已同步到 $latest_tag"
}

collect_formulas() {
    local formula_files=()
    local formulas=()
    local formula_file

    shopt -s nullglob
    formula_files=("$FORMULA_DIR"/*.rb)
    shopt -u nullglob

    if [ "${#formula_files[@]}" -eq 0 ]; then
        echo "错误：$FORMULA_DIR 下没有找到 formula 文件" >&2
        return 1
    fi

    for formula_file in "${formula_files[@]}"; do
        formulas+=("$(normalize_formula_name "$formula_file")")
    done

    printf '%s\n' "${formulas[@]}"
}

main() {
    local formulas=()
    local formula arg
    local failures=()

    if [ "$#" -ne 0 ]; then
        for arg in "$@"; do
            case "$arg" in
                -h|--help)
                    usage
                    exit 0
                    ;;
                --debug)
                    DEBUG=1
                    ;;
                -*)
                    echo "错误：不支持的参数：$arg" >&2
                    exit 1
                    ;;
                *)
                    formulas+=("$(normalize_formula_name "$arg")")
                    ;;
            esac
        done
    fi

    if [ "${#formulas[@]}" -eq 0 ]; then
        while IFS= read -r formula; do
            [ -n "$formula" ] && formulas+=("$formula")
        done < <(collect_formulas)
    fi

    FORMULA_COUNT="${#formulas[@]}"
    export FORMULA_COUNT

    for formula in "${formulas[@]}"; do
        if ! update_formula "$formula"; then
            failures+=("$formula")
        fi
    done

    if [ "${#failures[@]}" -ne 0 ]; then
        echo "失败的公式：${failures[*]}" >&2
        exit 1
    fi
}

main "$@"
