#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { spawn } from 'child_process';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config();

class CodexMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'mcp-codex-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );
    
    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'codex_review',
          description: 'Request a code review or evaluation from Codex. Use this for reviewing changes, plans, or getting peer review on implementations.',
          inputSchema: {
            type: 'object',
            properties: {
              prompt: {
                type: 'string',
                description: 'The review request or question for Codex'
              },
              include_project_context: {
                type: 'boolean',
                description: 'Include CLAUDE.md as project context (default: true)',
                default: true
              }
            },
            required: ['prompt']
          }
        },
        {
          name: 'codex_consult',
          description: 'Consult with Codex about implementation decisions, best practices, or get guidance on how to approach a problem.',
          inputSchema: {
            type: 'object',
            properties: {
              question: {
                type: 'string',
                description: 'The question or topic to discuss with Codex'
              }
            },
            required: ['question']
          }
        },
        {
          name: 'codex_status',
          description: 'Get a summary of the current project state from Codex',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        },
        {
          name: 'codex_history',
          description: 'View past Codex consultation sessions',
          inputSchema: {
            type: 'object',
            properties: {
              limit: {
                type: 'number',
                description: 'Number of recent sessions to show (default: 5)',
                default: 5
              }
            }
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'codex_review':
            return await this.handleCodexReview(args);
          case 'codex_consult':
            return await this.handleCodexConsult(args);
          case 'codex_status':
            return await this.handleCodexStatus();
          case 'codex_history':
            return await this.handleCodexHistory(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ]
        };
      }
    });
  }

  async executeCodex(args) {
    // Check if OPENAI_API_KEY is set
    if (!process.env.OPENAI_API_KEY) {
      // Try to source .env file
      const envPath = path.join(process.cwd(), '.env');
      try {
        const envContent = await fs.readFile(envPath, 'utf-8');
        const match = envContent.match(/OPENAI_API_KEY=(.+)/);
        if (match) {
          process.env.OPENAI_API_KEY = match[1].trim();
        }
      } catch (err) {
        throw new Error('OPENAI_API_KEY not found. Please set it in your environment or .env file.');
      }
    }

    return new Promise((resolve, reject) => {
      // Build the command
      const cmd = 'codex';
      const cmdArgs = ['-q', ...args]; // Always use quiet mode for Docker compatibility
      
      const proc = spawn(cmd, cmdArgs, {
        env: process.env,
        shell: true
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
          reject(new Error(`Codex exited with code ${code}: ${stderr || stdout}`));
        } else {
          resolve(stdout);
        }
      });

      proc.on('error', (err) => {
        reject(new Error(`Failed to execute codex: ${err.message}`));
      });
    });
  }

  async handleCodexReview(args) {
    const { prompt, include_project_context = true } = args;
    
    const codexArgs = [];
    if (include_project_context && await this.fileExists('CLAUDE.md')) {
      codexArgs.push('--project-doc', 'CLAUDE.md');
    }
    codexArgs.push(prompt);

    const output = await this.executeCodex(codexArgs);
    
    return {
      content: [
        {
          type: 'text',
          text: `Codex Review Response:\n\n${output}`
        }
      ]
    };
  }

  async handleCodexConsult(args) {
    const { question } = args;
    
    const output = await this.executeCodex([question]);
    
    return {
      content: [
        {
          type: 'text',
          text: `Codex Consultation:\n\n${output}`
        }
      ]
    };
  }

  async handleCodexStatus() {
    const output = await this.executeCodex(['summarize the current state of the project']);
    
    return {
      content: [
        {
          type: 'text',
          text: `Project Status from Codex:\n\n${output}`
        }
      ]
    };
  }

  async handleCodexHistory(args) {
    const { limit = 5 } = args;
    
    try {
      const output = await this.executeCodex(['--history']);
      
      // Parse and limit the history output
      const lines = output.split('\n');
      const sessions = [];
      let currentSession = '';
      
      for (const line of lines) {
        if (line.startsWith('Session:') && currentSession) {
          sessions.push(currentSession);
          currentSession = line;
        } else {
          currentSession += line + '\n';
        }
      }
      
      if (currentSession) {
        sessions.push(currentSession);
      }
      
      const limitedSessions = sessions.slice(0, limit).join('\n---\n');
      
      return {
        content: [
          {
            type: 'text',
            text: `Recent Codex Sessions (showing ${Math.min(limit, sessions.length)} of ${sessions.length}):\n\n${limitedSessions}`
          }
        ]
      };
    } catch (error) {
      // If history command fails, provide helpful message
      return {
        content: [
          {
            type: 'text',
            text: 'No history available or codex --history command not supported.'
          }
        ]
      };
    }
  }

  async fileExists(filePath) {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Codex MCP Server running on stdio');
  }
}

// Run the server
const server = new CodexMCPServer();
server.run().catch(console.error);