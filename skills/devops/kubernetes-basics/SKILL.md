---
name: kubernetes-basics
description: Kubernetes core concepts, manifest patterns for Spring Boot deployments, ConfigMap/Secret management, Ingress, HPA autoscaling, health probes, and production readiness checklist.
---

# Kubernetes Best Practices

## Core Resource Patterns

### Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
    version: "1.0.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0        # Zero-downtime deploy
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: registry/myapp:abc1234
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "production"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: myapp-secrets
                  key: db-password
          envFrom:
            - configMapRef:
                name: myapp-config
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 20
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            failureThreshold: 30
            periodSeconds: 5    # 150s total startup grace period
      terminationGracePeriodSeconds: 60
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
spec:
  type: ClusterIP              # Internal only; use Ingress for external
  selector:
    app: myapp
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

### Ingress (nginx)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts: [api.example.com]
      secretName: myapp-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

### ConfigMap & Secret
```yaml
# ConfigMap — non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  SPRING_DATASOURCE_URL: "jdbc:mysql://mysql-svc:3306/mydb"
  JWT_ACCESS_EXPIRY: "3600000"
  CORS_ALLOWED_ORIGINS: "https://app.example.com"

---
# Secret — sensitive data (base64 encoded)
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: production
type: Opaque
stringData:                    # stringData auto base64-encodes
  db-password: "my-secret-pass"
  jwt-secret: "my-jwt-secret"
```

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

## Spring Boot Actuator for K8s

```yaml
# application.yml — expose health endpoints for probes
management:
  endpoint:
    health:
      probes:
        enabled: true          # /actuator/health/liveness, /actuator/health/readiness
      show-details: always
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

## Namespace & RBAC

```yaml
# Separate environments with namespaces
kubectl create namespace staging
kubectl create namespace production

# ResourceQuota per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

## Common kubectl Commands

```bash
# Apply manifests
kubectl apply -f k8s/

# Watch rollout
kubectl rollout status deployment/myapp -n production

# Rollback
kubectl rollout undo deployment/myapp -n production

# View logs
kubectl logs -f deployment/myapp -n production --tail=100

# Exec into pod
kubectl exec -it deployment/myapp -n production -- sh

# Port forward for debugging
kubectl port-forward svc/myapp 8080:80 -n production

# Scale manually
kubectl scale deployment myapp --replicas=5 -n production

# Describe resource for troubleshooting
kubectl describe pod <pod-name> -n production
```

## Production Readiness Checklist

- [ ] `resources.requests` and `resources.limits` set on all containers
- [ ] `readinessProbe` configured (gates traffic)
- [ ] `livenessProbe` configured (restarts unhealthy pods)
- [ ] `startupProbe` configured for slow-starting apps
- [ ] `replicas >= 2` for HA
- [ ] `maxUnavailable: 0` for zero-downtime rolling updates
- [ ] `PodDisruptionBudget` set for critical services
- [ ] Secrets stored in Secret (not ConfigMap or env literals)
- [ ] Image tagged with SHA, not `latest`
- [ ] Namespace + ResourceQuota defined
- [ ] Network policies applied (deny-all default + explicit allows)
