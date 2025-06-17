#!/usr/bin/env node

// Test script for MCP Codex Server
// This simulates MCP client requests to verify the server works correctly

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class MCPTestClient {
  constructor() {
    this.serverPath = path.join(__dirname, 'index.js');
  }

  async sendRequest(request) {
    return new Promise((resolve, reject) => {
      const proc = spawn('node', [this.serverPath], {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      proc.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      proc.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Server exited with code ${code}: ${stderr}`));
        } else {
          try {
            // Parse JSON-RPC response
            const lines = stdout.split('\n').filter(line => line.trim());
            const response = JSON.parse(lines[lines.length - 1]);
            resolve(response);
          } catch (err) {
            resolve({ stdout, stderr });
          }
        }
      });

      // Send JSON-RPC request
      proc.stdin.write(JSON.stringify(request) + '\n');
      proc.stdin.end();
    });
  }

  async testListTools() {
    console.log('Testing tools/list...');
    const response = await this.sendRequest({
      jsonrpc: '2.0',
      method: 'tools/list',
      id: 1
    });
    
    console.log('Available tools:');
    if (response.result && response.result.tools) {
      response.result.tools.forEach(tool => {
        console.log(`  - ${tool.name}: ${tool.description}`);
      });
    }
  }

  async testCodexReview() {
    console.log('\nTesting codex_review tool...');
    const response = await this.sendRequest({
      jsonrpc: '2.0',
      method: 'tools/call',
      params: {
        name: 'codex_review',
        arguments: {
          prompt: 'test review request',
          include_project_context: false
        }
      },
      id: 2
    });
    
    console.log('Response:', JSON.stringify(response, null, 2));
  }

  async runTests() {
    console.log('MCP Codex Server Test Suite\n');
    
    try {
      await this.testListTools();
      
      // Only test actual tool calls if OPENAI_API_KEY is set
      if (process.env.OPENAI_API_KEY) {
        await this.testCodexReview();
      } else {
        console.log('\nSkipping tool execution tests (OPENAI_API_KEY not set)');
      }
      
      console.log('\n✓ All tests completed');
    } catch (error) {
      console.error('\n✗ Test failed:', error.message);
      process.exit(1);
    }
  }
}

// Run tests
const client = new MCPTestClient();
client.runTests();