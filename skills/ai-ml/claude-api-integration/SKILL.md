---
name: claude-api-integration
description: Anthropic Claude API integration patterns using the Anthropic SDK for Python and TypeScript/Node.js. Covers messages API, streaming, tool use, system prompts, multi-turn conversations, and production best practices.
---

# Claude API Integration Best Practices

## Setup

### TypeScript / Node.js
```bash
npm install @anthropic-ai/sdk
```

```typescript
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,  // Never hardcode
});
```

### Python
```bash
pip install anthropic
```

```python
import anthropic

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
```

## Basic Message

```typescript
// TypeScript
const message = await client.messages.create({
  model: 'claude-sonnet-4-6',
  max_tokens: 1024,
  system: 'You are a helpful assistant that answers concisely in Korean.',
  messages: [
    { role: 'user', content: 'REST API와 GraphQL의 차이점을 설명해줘.' }
  ],
});

console.log(message.content[0].text);
```

```python
# Python
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="You are a helpful assistant.",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(message.content[0].text)
```

## Streaming

```typescript
// TypeScript streaming
const stream = await client.messages.stream({
  model: 'claude-sonnet-4-6',
  max_tokens: 2048,
  messages: [{ role: 'user', content: prompt }],
});

// Stream to HTTP response (Express/Fastify/Next.js)
for await (const chunk of stream) {
  if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
    res.write(`data: ${JSON.stringify({ text: chunk.delta.text })}\n\n`);
  }
}
res.end();

// Or use the helper
const finalMessage = await stream.finalMessage();
```

```python
# Python streaming
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

## Tool Use (Function Calling)

```typescript
const tools: Anthropic.Tool[] = [
  {
    name: 'get_weather',
    description: '특정 도시의 현재 날씨를 조회합니다.',
    input_schema: {
      type: 'object',
      properties: {
        city: { type: 'string', description: '도시명 (예: 서울)' },
        unit: { type: 'string', enum: ['celsius', 'fahrenheit'], default: 'celsius' },
      },
      required: ['city'],
    },
  },
];

async function runWithTools(userMessage: string) {
  const messages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage }
  ];

  while (true) {
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      tools,
      messages,
    });

    if (response.stop_reason === 'end_turn') {
      return response.content[0].type === 'text' ? response.content[0].text : '';
    }

    if (response.stop_reason === 'tool_use') {
      // Add assistant response to history
      messages.push({ role: 'assistant', content: response.content });

      // Execute tool calls
      const toolResults: Anthropic.ToolResultBlockParam[] = [];
      for (const block of response.content) {
        if (block.type === 'tool_use') {
          const result = await executeTool(block.name, block.input);
          toolResults.push({
            type: 'tool_result',
            tool_use_id: block.id,
            content: JSON.stringify(result),
          });
        }
      }

      messages.push({ role: 'user', content: toolResults });
    }
  }
}
```

## Multi-Turn Conversation

```typescript
class ConversationManager {
  private history: Anthropic.MessageParam[] = [];
  private readonly systemPrompt: string;

  constructor(systemPrompt: string) {
    this.systemPrompt = systemPrompt;
  }

  async chat(userMessage: string): Promise<string> {
    this.history.push({ role: 'user', content: userMessage });

    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 2048,
      system: this.systemPrompt,
      messages: this.history,
    });

    const assistantMessage = response.content[0].type === 'text'
      ? response.content[0].text
      : '';

    this.history.push({ role: 'assistant', content: assistantMessage });

    // Trim history to prevent context overflow (keep last N turns)
    if (this.history.length > 20) {
      this.history = this.history.slice(-20);
    }

    return assistantMessage;
  }

  reset() { this.history = []; }
}
```

## Structured Output

```typescript
// Request JSON output via system prompt + response parsing
const response = await client.messages.create({
  model: 'claude-sonnet-4-6',
  max_tokens: 1024,
  system: 'Respond only with valid JSON. No markdown, no explanation.',
  messages: [{
    role: 'user',
    content: `Extract the following from this text and return as JSON:
    { "name": string, "email": string, "company": string }

    Text: "${inputText}"`
  }],
});

const parsed = JSON.parse(response.content[0].text);
```

## Error Handling & Retry

```typescript
import Anthropic from '@anthropic-ai/sdk';

async function callWithRetry(params: Anthropic.MessageCreateParams, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await client.messages.create(params);
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        if (attempt === maxRetries) throw error;
        await new Promise(r => setTimeout(r, 2 ** attempt * 1000)); // exponential backoff
        continue;
      }
      if (error instanceof Anthropic.APIError) {
        if (error.status >= 500 && attempt < maxRetries) continue;
      }
      throw error;
    }
  }
}
```

## Model Selection Guide

```
claude-opus-4-6    → Complex reasoning, architecture analysis, deep research
claude-sonnet-4-6  → Standard tasks, code generation, document writing (best balance)
claude-haiku-4-5   → Fast lookups, simple tasks, high-volume classification
```

## Best Practices

- Store `ANTHROPIC_API_KEY` in environment variables / secrets manager only
- Set `max_tokens` explicitly — never rely on defaults
- Use `system` prompt for persistent instructions (persona, format, constraints)
- For structured output, validate with Zod/Pydantic after parsing
- Implement exponential backoff for rate limit errors (429)
- Log `model`, `input_tokens`, `output_tokens` from response for cost tracking
- Use streaming for responses > 500 tokens to improve perceived latency
- Cache identical prompts at application layer to reduce API costs
