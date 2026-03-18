---
name: prompt-engineering
description: Prompt engineering techniques for Claude and other LLMs including system prompt design, chain-of-thought, few-shot examples, output formatting, and anti-patterns to avoid.
---

# Prompt Engineering Best Practices

## System Prompt Design

```
Structure of a good system prompt:
1. Role / Persona        — who the model is
2. Context               — background information
3. Task scope            — what it should and shouldn't do
4. Output format         — structure, language, length
5. Constraints           — rules, tone, what to avoid
```

```
Good system prompt example:
─────────────────────────────────────────────────────
You are a senior backend developer assistant specializing in Spring Boot and Java.

Context:
- The project uses Spring Boot 3.3, Java 17, MySQL, and hexagonal architecture
- Code style: no service interfaces, concrete @Service classes only
- All responses should be in Korean

Tasks you handle:
- Code review and bug identification
- Architecture recommendations
- Writing unit and integration tests

Output format:
- Lead with the direct answer or code
- Use code blocks with language tags
- Keep explanations concise

Constraints:
- Do not suggest switching frameworks
- Do not add unnecessary abstractions
- Always prefer simple solutions over complex ones
─────────────────────────────────────────────────────
```

## Chain-of-Thought (CoT)

```
Use when: complex reasoning, math, multi-step logic, debugging

# Basic CoT trigger
"Think step by step before answering."

# Structured CoT
"Before giving your answer:
1. Identify the core problem
2. List possible approaches
3. Evaluate trade-offs
4. Recommend the best approach
Then provide the solution."

# Zero-shot CoT (just add this phrase)
"Let's think through this carefully."
```

## Few-Shot Examples

```
Use when: specific output format required, consistent style needed

System: Classify the sentiment of customer reviews as POSITIVE, NEGATIVE, or NEUTRAL.

Examples:
User: "배송이 너무 빨라서 깜짝 놀랐어요. 포장도 완벽했습니다."
Assistant: POSITIVE

User: "상품 설명과 실제 제품이 완전히 달랐습니다. 환불하겠습니다."
Assistant: NEGATIVE

User: "보통이에요. 특별히 좋지도 나쁘지도 않네요."
Assistant: NEUTRAL

User: [actual input]
```

## Output Format Control

```
# JSON output
"Respond with a JSON object only. No explanation, no markdown.
Schema: { "name": string, "score": number, "reason": string }"

# Markdown structure
"Format your response as:
## Summary
[1-2 sentences]

## Details
[bullet points]

## Recommendation
[single clear action]"

# Constrained length
"Answer in exactly 3 bullet points, each under 15 words."

# Table format
"Present the comparison as a markdown table with columns:
| Feature | Option A | Option B | Recommendation |"
```

## Role Prompting

```
Effective roles for engineering tasks:
- "You are a senior security engineer reviewing this code for vulnerabilities."
- "You are a database performance expert. Analyze this query for optimization."
- "You are a technical writer creating documentation for junior developers."
- "You are a code reviewer with high standards. Be thorough and critical."

Avoid vague roles:
- ❌ "You are an expert." (too generic)
- ✅ "You are a Java performance engineer specializing in JVM tuning."
```

## XML Tags for Structure (Claude-specific)

```
Claude handles XML tags natively — use them to separate content:

<instructions>
Review the following code for bugs and security issues.
Focus on: null safety, SQL injection, authentication gaps.
</instructions>

<code>
[paste code here]
</code>

<output_format>
List each issue as:
- Severity: HIGH/MEDIUM/LOW
- Location: file:line
- Issue: description
- Fix: recommended solution
</output_format>
```

## Prompt Patterns

### Persona + Task + Format
```
You are [ROLE].
[CONTEXT about the situation]
Your task: [SPECIFIC TASK]
Output format: [FORMAT REQUIREMENTS]
Input: [USER INPUT]
```

### ReAct (Reason + Act)
```
"For each step:
1. THOUGHT: What do I know and what do I need to figure out?
2. ACTION: What should I do next?
3. OBSERVATION: What did I find?
Repeat until you have enough information to answer."
```

### Self-Consistency
```
"Generate 3 different approaches to this problem.
Then evaluate each approach.
Finally, recommend the best one and explain why."
```

### Iterative Refinement
```
# Turn 1
"Draft a technical spec for [feature]."

# Turn 2
"Review the spec you wrote. Identify gaps, ambiguities, and missing edge cases."

# Turn 3
"Rewrite the spec addressing all the issues you identified."
```

## Anti-Patterns to Avoid

```
❌ Vague instructions
"Make this better."
✅ "Refactor this function to reduce cyclomatic complexity below 5 and add error handling."

❌ Negative-only constraints
"Don't use recursion."
✅ "Use iteration instead of recursion."

❌ Overloading single prompt
"Review the code, write tests, update the docs, and create a PR description."
✅ Break into sequential prompts with one task each.

❌ No output format specified
"List the issues."
✅ "List each issue as: [Severity] - [File:Line] - [Description]"

❌ Assuming context
"Fix the bug."
✅ "The function returns null when input is empty. Fix it to return an empty list instead."
```

## Temperature Guide

```
Task                           → Temperature
─────────────────────────────────────────────
Code generation / debugging    → 0.0 - 0.2  (deterministic)
Data extraction / classification → 0.0      (exact)
Technical documentation        → 0.2 - 0.5  (consistent + slight variation)
Brainstorming / ideation       → 0.7 - 1.0  (creative)
Creative writing               → 0.8 - 1.0  (diverse)
```

## Prompt Testing Checklist

- [ ] Tested with edge cases (empty input, very long input, unexpected formats)
- [ ] Output format enforced and validated
- [ ] System prompt and user prompt separated correctly
- [ ] Temperature set appropriately for the task
- [ ] Token limits sufficient for expected output
- [ ] Evaluated on 5+ representative examples before production
