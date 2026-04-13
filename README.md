# media-metadata-viewer

在 macOS 上通过命令行查看**本地**图片或音视频文件的元数据：图片使用 **ImageIO**（含 EXIF / GPS / TIFF / IPTC 等属性字典），视频使用 **AVFoundation**（容器级 `metadata` / `commonMetadata`，以及 **metadata 轨道**上的定时元数据）。

## 要求

- macOS **11** 或更高
- Swift **6**（与 `Package.swift` 中 `swift-tools-version` 一致）
- Xcode 或 Swift 工具链，用于构建

## 构建

```bash
cd media-metadata-viewer
swift build -c release
```

可执行文件路径示例：

- Debug：`.build/debug/media-metadata-viewer`
- Release：`.build/release/media-metadata-viewer`

也可直接：

```bash
swift run media-metadata-viewer --help
```

## 用法

```text
media-metadata-viewer --path <文件路径> [--format text|json]
```

| 选项 | 简写 | 说明 |
|------|------|------|
| `--path` | `-p` | 本地媒体文件路径（必填） |
| `--format` | `-f` | 输出格式：`text`（默认）或 `json` |

### 示例

```bash
# 人类可读
./.build/release/media-metadata-viewer -p ./photo.jpg -f text

# 管道给 jq
./.build/release/media-metadata-viewer -p ./clip.mov -f json | jq
```

## 类型判定

顺序大致为：扩展属性中的 `contentType` → 扩展名推断 `UTType` → 必要时读取文件头 **sniff**。  
`UTType` 符合 `image` 时走 ImageIO；符合常见音视频 / `audio` 时走 AVFoundation。无法识别时会报错。

## JSON 输出结构（概要）

**图片**

- `mediaKind`: `"image"`
- `utType`: 统一类型标识符字符串
- `properties`: ImageIO 属性字典（已做 JSON 友好转换；二进制为带 `base64` 的对象）

**视频**

- `mediaKind`: `"video"`
- `utType`
- `video`
  - `container`
    - `metadata` / `commonMetadata`：`AVMetadataItem` 解析后的条目数组
  - `metadataTracks`：每条 metadata 轨含 `trackID`、`timeRange`、`formatDescriptions` 等
    - `timedMetadataGroups`：由 `AVAssetReaderOutputMetadataAdaptor` 读出的定时组，每组含 `timeRange` 与 `items`

无效时间戳或无法序列化的浮点数在 JSON 中可能为 `null`（避免 `NaN` 导致序列化失败）。

## 开发说明

更细的约定与文件分工见仓库内 [`AGENTS.md`](AGENTS.md)。

## 许可

[MIT License](LICENSE)
