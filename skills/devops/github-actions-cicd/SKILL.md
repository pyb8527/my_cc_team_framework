---
name: github-actions-cicd
description: GitHub Actions CI/CD pipeline best practices for Spring Boot and Node.js projects including build, test, Docker image publishing, deployment to AWS/GCP, and branch protection strategies.
---

# GitHub Actions CI/CD Best Practices

## Spring Boot — CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    name: Build & Test
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: test
          MYSQL_DATABASE: testdb
        ports: ["3306:3306"]
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=5

    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: gradle

      - name: Grant execute permission
        run: chmod +x gradlew

      - name: Run tests
        run: ./gradlew test --no-daemon
        env:
          SPRING_DATASOURCE_URL: jdbc:mysql://localhost:3306/testdb?useSSL=false&allowPublicKeyRetrieval=true
          SPRING_DATASOURCE_USERNAME: root
          SPRING_DATASOURCE_PASSWORD: test

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: test-results
          path: '**/build/reports/tests/'

      - name: Build jar
        run: ./gradlew bootJar --no-daemon -x test
```

## CD Pipeline — Docker + AWS ECR

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: my-app
  ECS_SERVICE: my-app-service
  ECS_CLUSTER: my-cluster

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # OIDC
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, push image
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --force-new-deployment
```

## Node.js / Next.js — CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Type check
        run: npm run type-check

      - name: Lint
        run: npm run lint

      - name: Unit tests
        run: npm run test:ci

      - name: Build
        run: npm run build
        env:
          NEXT_PUBLIC_API_URL: ${{ vars.NEXT_PUBLIC_API_URL }}
```

## Reusable Workflow

```yaml
# .github/workflows/reusable-docker-build.yml
name: Reusable Docker Build

on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
      tag:
        required: true
        type: string
    secrets:
      registry-password:
        required: true
    outputs:
      image-tag:
        value: ${{ jobs.build.outputs.tag }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ inputs.image-name }}
          tags: type=sha,value=${{ inputs.tag }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
```

## Security Scanning

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

## Concurrency Control

```yaml
# Cancel in-progress runs on same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Environment & Secrets Strategy

```yaml
# Use environments for deployment gates
jobs:
  deploy-staging:
    environment: staging         # Requires reviewer approval
    env:
      API_URL: ${{ vars.STAGING_API_URL }}       # Non-secret vars
      DB_PASSWORD: ${{ secrets.STAGING_DB_PASS }} # Secrets

  deploy-production:
    needs: deploy-staging
    environment: production      # Requires manual approval + protection rules
```

## Best Practices

- Use OIDC (`id-token: write`) instead of long-lived AWS/GCP credentials
- Pin action versions to SHA (`actions/checkout@v4` → `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`)
- Use `concurrency` to cancel redundant runs on feature branches
- Cache dependencies (`cache: gradle`, `cache: npm`) to speed up builds
- Never print secrets with `echo` — they'll appear in logs
- Use `environment` for production with required reviewers
- Separate CI (every PR) from CD (main only) workflows
- Run security scans (Trivy, CodeQL) on every merge to main
