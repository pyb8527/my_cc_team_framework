---
name: rag-patterns
description: Retrieval-Augmented Generation (RAG) architecture patterns including document ingestion, chunking strategies, vector store integration (pgvector, Pinecone, Qdrant), embedding models, and production RAG pipelines with LangChain and LlamaIndex.
---

# RAG (Retrieval-Augmented Generation) Patterns

## RAG Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   INDEXING PIPELINE                 │
│  Documents → Chunk → Embed → Store in Vector DB     │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│                   QUERY PIPELINE                    │
│  Query → Embed → Similarity Search → Retrieve       │
│       → Augment Prompt → LLM → Response             │
└─────────────────────────────────────────────────────┘
```

## Document Chunking Strategy

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Recursive splitter (best for most documents)
splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,          # tokens per chunk
    chunk_overlap=64,        # overlap to preserve context
    separators=["\n\n", "\n", ". ", " ", ""],
)

chunks = splitter.split_documents(documents)

# For code — use language-aware splitter
from langchain.text_splitter import Language, RecursiveCharacterTextSplitter
code_splitter = RecursiveCharacterTextSplitter.from_language(
    language=Language.PYTHON,
    chunk_size=1000,
    chunk_overlap=100,
)
```

### Chunking Strategy Guide
```
Document type          → Chunk size    → Strategy
─────────────────────────────────────────────────
General prose          → 300-500 tok   → Recursive
Technical docs         → 500-800 tok   → Recursive + overlap 10%
Code                   → 500-1000 tok  → Language-aware
Q&A / FAQ              → ~200 tok      → One Q&A per chunk
Tables / structured    → variable      → Row/section-based
```

## Embedding Models

```python
# OpenAI embeddings
from langchain_openai import OpenAIEmbeddings
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")  # 1536 dims

# Sentence Transformers (open-source, free)
from langchain_huggingface import HuggingFaceEmbeddings
embeddings = HuggingFaceEmbeddings(
    model_name="BAAI/bge-m3",   # multilingual (Korean supported)
    model_kwargs={"device": "cpu"},
    encode_kwargs={"normalize_embeddings": True},
)

# Anthropic doesn't provide embedding API — use OpenAI or open-source
```

## Vector Store Integration

### pgvector (PostgreSQL)
```python
from langchain_postgres import PGVector

vector_store = PGVector(
    embeddings=embeddings,
    collection_name="documents",
    connection="postgresql+psycopg://user:pass@localhost:5432/mydb",
    use_jsonb=True,
)

# Add documents
vector_store.add_documents(chunks)

# Similarity search
results = vector_store.similarity_search(query, k=5)

# Similarity search with score
results = vector_store.similarity_search_with_score(query, k=5)
# Returns (Document, score) — score: 0=identical, 2=opposite (cosine distance)
```

```sql
-- pgvector setup
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    metadata JSONB,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index for fast approximate search
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

### Qdrant (Dedicated Vector DB)
```python
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

client = QdrantClient(url="http://localhost:6333")

vector_store = QdrantVectorStore(
    client=client,
    collection_name="documents",
    embedding=embeddings,
)
```

## Basic RAG Chain (LangChain)

```python
from langchain_anthropic import ChatAnthropic
from langchain.chains import create_retrieval_chain
from langchain.chains.combine_documents import create_stuff_documents_chain
from langchain_core.prompts import ChatPromptTemplate

llm = ChatAnthropic(model="claude-sonnet-4-6", max_tokens=2048)

retriever = vector_store.as_retriever(
    search_type="similarity",
    search_kwargs={"k": 5},
)

prompt = ChatPromptTemplate.from_template("""
다음 컨텍스트를 기반으로 질문에 답해주세요.
컨텍스트에 답이 없으면 모른다고 말하세요.

컨텍스트:
{context}

질문: {input}

답변:
""")

document_chain = create_stuff_documents_chain(llm, prompt)
rag_chain = create_retrieval_chain(retriever, document_chain)

response = rag_chain.invoke({"input": "회사 휴가 정책은 어떻게 되나요?"})
print(response["answer"])
```

## Advanced RAG Patterns

### Hybrid Search (Keyword + Semantic)
```python
from langchain_community.retrievers import BM25Retriever
from langchain.retrievers import EnsembleRetriever

# BM25 for keyword matching
bm25_retriever = BM25Retriever.from_documents(documents, k=3)

# Dense retrieval for semantic matching
dense_retriever = vector_store.as_retriever(search_kwargs={"k": 3})

# Ensemble combines both
ensemble_retriever = EnsembleRetriever(
    retrievers=[bm25_retriever, dense_retriever],
    weights=[0.4, 0.6],  # weight toward semantic
)
```

### Re-ranking
```python
from langchain.retrievers import ContextualCompressionRetriever
from langchain_cohere import CohereRerank

# Retrieve more, then re-rank to top-k
compressor = CohereRerank(model="rerank-multilingual-v3.0", top_n=3)
compression_retriever = ContextualCompressionRetriever(
    base_compressor=compressor,
    base_retriever=dense_retriever,  # retrieve 10, rerank to 3
)
```

### Metadata Filtering
```python
# Filter by document source, date, category
results = vector_store.similarity_search(
    query,
    k=5,
    filter={"source": "hr-policy.pdf", "year": 2024},
)
```

## Ingestion Pipeline

```python
from langchain_community.document_loaders import PyPDFLoader, DirectoryLoader
from pathlib import Path

async def ingest_documents(directory: str):
    # Load
    loader = DirectoryLoader(directory, glob="**/*.pdf", loader_cls=PyPDFLoader)
    documents = loader.load()

    # Add metadata
    for doc in documents:
        doc.metadata["ingested_at"] = datetime.now().isoformat()

    # Split
    splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)
    chunks = splitter.split_documents(documents)

    # Embed + Store (batch for efficiency)
    await vector_store.aadd_documents(chunks, batch_size=100)
    return len(chunks)
```

## Best Practices

- **Chunking**: Overlap 10-15% of chunk size to preserve context at boundaries
- **Retrieval**: Start with k=5, evaluate with RAGAS metrics, tune up/down
- **Prompts**: Instruct LLM to say "I don't know" when context is insufficient
- **Metadata**: Store source, page, section — crucial for citations and filtering
- **Evaluation**: Use RAGAS (faithfulness, answer relevancy, context precision)
- **Hybrid search**: Combine BM25 + semantic for better recall on exact terms
- **Re-ranking**: Add a cross-encoder re-ranker for production quality boost
- **Caching**: Cache embeddings of frequently searched queries
