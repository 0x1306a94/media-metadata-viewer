# AGENTS.md — media-metadata-viewer

## 项目概要

- **用途**：本地图片/视频元数据 CLI（ImageIO 读图；AVFoundation 读容器 metadata 与 metadata 轨）。
- **栈**：Swift 6、SwiftPM、`ArgumentParser`；最低 **macOS 11**；链接 **ImageIO / AVFoundation / UniformTypeIdentifiers**。
- **入口**：`[Sources/MediaMetadataViewer.swift](Sources/MediaMetadataViewer.swift)`（`@main`）。**不要用** `main.swift` 作文件名，否则与 `@main` 冲突。

## 代码布局


| 文件                          | 职责                                                                                        |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| `TypeDetection.swift`       | UTType / 扩展名 / 文件头 sniff，分流 image vs video                                                |
| `ImageMetadata.swift`       | `CGImageSourceCopyPropertiesAtIndex`                                                      |
| `VideoMetadata.swift`       | `AVURLAsset`、metadata 项、`AVAssetReaderOutputMetadataAdaptor` + `nextTimedMetadataGroup()` |
| `JSONCompatibleValue.swift` | 转为可 JSON 序列化结构；浮点须 `isFinite`（避免 NaN 写 JSON 崩溃）                                           |
| `MetadataOutput.swift`      | `--format text|json`、`OutputFormat`                                                       |
| `MediaMetadataError.swift`  | `LocalizedError`                                                                          |


## 实现注意点

- **Metadata 轨**：使用 `AVAssetReaderOutputMetadataAdaptor`，**禁止**在同一 `AVAssetReaderTrackOutput` 上再调用 `copyNextSampleBuffer()`。
- **AVAssetTrack** 异步加载：不要使用不存在的 KVO key（例如 `"duration"`）；用已加载的 `timeRange`。
- **JSON**：`CMTimeGetSeconds` 等可能产生非有限值，输出前统一做 `jsonSafe`/`JSONCompatibleValue` 处理。
- **并发**：`@preconcurrency import AVFoundation` 用于缓解 `AVAsset` 等与 `Sendable` 相关的闭包检查。

## 验证

- 修改后执行：`swift build`。
- 有音视频行为变更时，用本地样例文件跑 `--format text` 与 `--format json`。

