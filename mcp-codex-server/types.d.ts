// Type definitions for MCP Codex Server

export interface CodexReviewArgs {
  prompt: string;
  include_project_context?: boolean;
}

export interface CodexConsultArgs {
  question: string;
}

export interface CodexHistoryArgs {
  limit?: number;
}

export interface CodexTool {
  name: 'codex_review' | 'codex_consult' | 'codex_status' | 'codex_history';
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, any>;
    required?: string[];
  };
}

export interface CodexResponse {
  content: Array<{
    type: 'text';
    text: string;
  }>;
}