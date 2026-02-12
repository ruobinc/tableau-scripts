# Copilot Studio × Tableau MCP 互換性の問題

## 前提: MCPの通信の仕組み

Copilot StudioがMCPサーバーに接続すると、まず `tools/list` というJSON-RPCリクエストを送り、使用可能なツール一覧を問い合わせる。MCPサーバーはJSON-RPCレスポンスとして、各ツールの名前・説明・入力パラメータのスキーマを返す。

```
Copilot Studio  --[tools/list リクエスト (JSON-RPC)]-->  Tableau MCP
Copilot Studio  <--[ツール一覧レスポンス (JSON-RPC)]---  Tableau MCP
                        ↓
              このJSONをパースして表示するツールを決める
```

Copilot Studioはこのレスポンスを解析し、パースに成功したツールのみをユーザーに表示する。以下の2つの問題は、いずれもこのレスポンスJSON内の値に起因する。

---

## 問題1: `exclusiveMinimum` のJSON Schemaバージョン不整合

### Tableau MCPのソースコード

Tableau MCPでは、ツールの入力パラメータをZodライブラリで定義している。例えば `list-views` ツール：

```typescript
// tableau-mcp/src/tools/views/listViews.ts
pageSize: z.number().gt(0).optional(),
limit: z.number().gt(0).optional(),
```

`.gt(0)` は「0より大きい」という制約。同様の定義が `list-workbooks`、`list-datasources`、`list-all-pulse-metric-definitions` 等の複数ツールに存在する。

### JSON Schemaへの自動変換

MCPサーバー起動時、ZodスキーマはJSON Schemaに自動変換される。`.gt(0)` は以下のJSON表現になる：

```json
{
  "inputSchema": {
    "properties": {
      "pageSize": {"type": "number", "exclusiveMinimum": 0},
      "limit": {"type": "number", "exclusiveMinimum": 0}
    }
  }
}
```

ソースコードに `exclusiveMinimum` と直接書かれているわけではなく、Zodが自動生成する。

### プロトコル仕様上の位置づけ

`exclusiveMinimum` はJSON Schemaの仕様に含まれるキーワードだが、ドラフトバージョンによって型が異なる：

| JSON Schema バージョン | `exclusiveMinimum` の型 | 例 |
|---|---|---|
| Draft 4 | boolean（`minimum`と併用） | `"minimum": 0, "exclusiveMinimum": true` |
| Draft 2020-12 | number（単独で使用） | `"exclusiveMinimum": 0` |

Zodが生成するのはDraft 2020-12形式（数値型）。MCP仕様自体はJSON Schemaのドラフトバージョンを明確に規定していない。

### なぜツールが表示されないか

Copilot Studioは `exclusiveMinimum` をboolean型（Draft 4形式）として解釈しようとする。数値 `0` をbooleanとしてパースできず `System.FormatException` が発生し、該当ツールがフィルタリング（非表示）される。

参考: [Microsoft Learn - MCP Troubleshooting](https://learn.microsoft.com/en-us/microsoft-copilot-studio/mcp-troubleshooting)

---

## 問題2: JSON-RPC `id` フィールドの型

### レスポンス内の該当箇所

`tools/list` のレスポンスはJSON-RPC 2.0形式で返される。各メッセージには `id` フィールドが含まれる：

```json
{"jsonrpc": "2.0", "id": 1, "result": {"tools": [...]}}
```

この `id: 1` が数値型である。

### プロトコル仕様上の位置づけ

| 仕様 | `id` の許容型 |
|---|---|
| [JSON-RPC 2.0](https://www.jsonrpc.org/specification) | String, Number, Null |
| [MCP仕様](https://modelcontextprotocol.io/specification/2025-06-18/schema) | `string \| number`（`RequestId`型） |

数値型の `id` はどちらの仕様でも正当。

### なぜツールが表示されない可能性があるか

Copilot Studioが `id` を文字列型のみ想定している場合、レスポンス全体のパースに失敗し、ツール一覧を正しく読み取れない可能性がある。ただし、Microsoft公式ドキュメントには明記されておらず、予防的な推測にとどまる。
[類似するコミュニティーの投稿](https://community.powerplatform.com/forums/thread/details/?threadid=7ec056e9-f950-f011-877a-7c1e5247028a)