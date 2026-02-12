/**
 * MCP Proxy Server for Copilot Studio
 * - JSON-RPC id フィールドを文字列に変換
 * - exclusiveMinimum/exclusiveMaximum を削除（Copilot Studio互換性）
 */

import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';

const PROXY_PORT = process.env.PROXY_PORT || 3928;
const TARGET_PORT = process.env.TARGET_PORT || 3927;
const TARGET_HOST = process.env.TARGET_HOST || 'localhost';

const app = express();

/**
 * Copilot Studio互換性のためにスキーマを修正
 * - exclusiveMinimum/exclusiveMaximum を削除（整数値はCopilot Studioでエラー）
 */
function fixSchemaForCopilotStudio(obj) {
  if (typeof obj !== 'object' || obj === null) return obj;

  if (Array.isArray(obj)) {
    return obj.map(item => fixSchemaForCopilotStudio(item));
  }

  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    if (key === 'exclusiveMinimum' || key === 'exclusiveMaximum') {
      continue;
    }
    result[key] = fixSchemaForCopilotStudio(value);
  }
  return result;
}

/**
 * レスポンスを変換
 */
function transformResponse(data) {
  try {
    let json = JSON.parse(data);

    // IDを文字列に変換
    if (json.id !== undefined && json.id !== null) {
      json.id = String(json.id);
    }

    // tools/list レスポンスの場合、スキーマを修正
    if (json.result && json.result.tools) {
      json.result.tools = json.result.tools.map(tool => {
        if (tool.inputSchema) {
          tool.inputSchema = fixSchemaForCopilotStudio(tool.inputSchema);
        }
        return tool;
      });
    }

    return JSON.stringify(json);
  } catch {
    return data;
  }
}

/**
 * SSE データ行を変換
 */
function transformSSELine(line) {
  if (line.startsWith('data: ')) {
    const data = line.slice(6);
    if (data.trim()) {
      return 'data: ' + transformResponse(data);
    }
  }
  return line;
}

// プロキシミドルウェア設定
const proxyMiddleware = createProxyMiddleware({
  target: `http://${TARGET_HOST}:${TARGET_PORT}`,
  changeOrigin: true,
  selfHandleResponse: true,

  on: {
    proxyRes: (proxyRes, req, res) => {
      const contentType = proxyRes.headers['content-type'] || '';

      // ヘッダーをコピー
      Object.keys(proxyRes.headers).forEach(key => {
        res.setHeader(key, proxyRes.headers[key]);
      });
      res.status(proxyRes.statusCode);

      // SSE ストリームの場合
      if (contentType.includes('text/event-stream')) {
        let buffer = '';

        proxyRes.on('data', (chunk) => {
          buffer += chunk.toString();
          const lines = buffer.split('\n');
          buffer = lines.pop();

          lines.forEach(line => {
            res.write(transformSSELine(line) + '\n');
          });
        });

        proxyRes.on('end', () => {
          if (buffer) res.write(transformSSELine(buffer));
          res.end();
        });

      // JSON レスポンスの場合
      } else if (contentType.includes('application/json')) {
        let body = '';

        proxyRes.on('data', (chunk) => {
          body += chunk.toString();
        });

        proxyRes.on('end', () => {
          const transformed = transformResponse(body);
          res.setHeader('content-length', Buffer.byteLength(transformed));
          res.end(transformed);
        });

      // その他のレスポンスはそのまま転送
      } else {
        proxyRes.pipe(res);
      }
    },

    error: (err, req, res) => {
      console.error('[Proxy Error]', err.message);
      if (!res.headersSent) {
        res.status(502).json({ error: 'Proxy error', message: err.message });
      }
    }
  }
});

// 全てのリクエストをプロキシ
app.use('/', proxyMiddleware);

app.listen(PROXY_PORT, () => {
  console.log(`MCP Proxy Server started`);
  console.log(`  Listening: http://0.0.0.0:${PROXY_PORT}`);
  console.log(`  Target:    http://${TARGET_HOST}:${TARGET_PORT}`);
  console.log(`  Transforms: id -> string, removes exclusiveMinimum/Maximum`);
});
