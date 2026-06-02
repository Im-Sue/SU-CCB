# PR Checklist

## 关联

- Issue：
- Spec / task：
- Parent：

## 改动摘要

请按文件或模块列出核心改动。

- 待补充
- 待补充
- 待补充

## 验收与测试结果

请粘贴实际运行过的命令和摘要输出。

```bash
python3 su-ccb-claude-plugin/references/kernel/tools/lint_all.py --legacy-baseline
```

```bash
pnpm -r build
pnpm -r test
```

如本 PR 只改文档，请补充 link check：

```bash
pnpm dlx markdown-link-check <file>
```

## 自审 checklist

- [ ] 改动范围与 issue/spec 一致。
- [ ] 没有修改无关文件或子模块 pointer。
- [ ] 没有引入未说明的新依赖。
- [ ] 没有修改 `su-ccb-claude-plugin/references/kernel/` 协议语义，或已说明 review 背景。
- [ ] 文档链接已验证。
- [ ] build / test / lint 结果已记录。
- [ ] 未验证项已明确写出。

## 风险与回滚

- 风险：
- 兼容性影响：
- 回滚方式：

## Review 关注点

请告诉 reviewer 你最希望重点看的地方。
