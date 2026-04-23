# belingud/homebrew-tap

## 仓库用途

这个仓库是 `belingud` 的 Homebrew tap。

当前维护：

- `gptcomet`
- `gh-download`
- `trash-cli-rs`

## 维护规则

- Formula 只放在 `Formula/` 目录下。
- Formula 统一固定 `url`、`tag`、`revision`、`version`。
- 只在确实需要时加特殊逻辑，例如：
  - `gptcomet` 需要安装 `gmsg` 软链接
  - `gptcomet` 需要 `caveats`
- `test do` 只保留最小有效校验。
- 新增 Formula 或调整维护流程时，同时更新 `README.md`。

## 新增 Formula

1. 确认上游仓库、最新 tag、对应 revision、命令名。
2. 新增 `Formula/<name>.rb`。
3. 至少检查：
   - `ruby -c Formula/<name>.rb`
   - `bash -n update_formulas.sh`
4. 确认变更范围后提交。

## 更新 Formula

用法：

```bash
./update_formulas.sh
./update_formulas.sh gptcomet
./update_formulas.sh gh-download
./update_formulas.sh trash-cli-rs
./update_formulas.sh --debug
```

规则：

- 不传参数时更新全部公式。
- 传入公式名时只更新指定公式。
- 先比较当前 `version`、`tag`、`revision`，有变化才写文件。
- 默认先查 GitHub Releases API，再解析 tag 对应 revision；必要时回退到远程 tag 列表。
