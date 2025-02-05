# Variablen (keine Einrückung!)
NAMESPACE ?= longhorn-system
VOLUME_NAME ?= rwx-volume
PVC_NAME ?= rwx-pvc
DEPLOYMENT_NAME ?= rwx-test
APP_PORT ?= 8081            # Port für die Anwendung
DASHBOARD_PORT ?= 8080      # Port für das Longhorn-Dashboard
KBENCH_DEPLOYMENT_NAME ?= kbench-test

## Hilfetext anzeigen
help: ## Zeigt diese Hilfe an
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## Longhorn installieren
install-longhorn: ## Installiert Longhorn im Cluster
	helm repo add longhorn https://charts.longhorn.io || true
	helm repo update
	kubectl create namespace $(NAMESPACE) || true
	helm install longhorn longhorn/longhorn --namespace $(NAMESPACE)

## Longhorn Volume erstellen
create-volume: ## Erstellt das RWX Volume
	@echo "Waiting for Longhorn API to be ready..."
	@until kubectl -n $(NAMESPACE) get pods | grep longhorn-manager | grep Running; do sleep 5; done
	@echo "Creating Longhorn Volume..."
	@kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: $(VOLUME_NAME)
spec:
  size: 1Gi
  numberOfReplicas: 3
  accessMode: rwx
EOF

## PersistentVolumeClaim erstellen
create-pvc: ## Erstellt den PVC für das RWX Volume
	@kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $(PVC_NAME)
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: $(VOLUME_NAME)
  storageClassName: longhorn
EOF

## Testdeployment erstellen
create-deployment: ## Erstellt das Testdeployment mit NGINX
	@kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $(DEPLOYMENT_NAME)
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $(DEPLOYMENT_NAME)
  template:
    metadata:
      labels:
        app: $(DEPLOYMENT_NAME)
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: rwx-storage
      volumes:
      - name: rwx-storage
        persistentVolumeClaim:
          claimName: $(PVC_NAME)
EOF

## Service für den Zugriff auf die Testanwendung erstellen (ClusterIP)
create-service: ## Erstellt einen ClusterIP-Service für das Testdeployment
	@kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $(DEPLOYMENT_NAME)-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: $(DEPLOYMENT_NAME)
EOF

## Longhorn-Dashboard verfügbar machen
expose-dashboard: ## Stellt das Longhorn-Dashboard über Port-Forwarding bereit
	@echo "Starting port-forwarding for Longhorn Dashboard on port $(DASHBOARD_PORT)..."
	@kubectl -n $(NAMESPACE) port-forward svc/longhorn-frontend $(DASHBOARD_PORT):80 &

## Anwendung über Port-Forwarding verfügbar machen
expose-app: ## Stellt die Testanwendung über Port-Forwarding bereit
	@echo "Starting port-forwarding for application on port $(APP_PORT)..."
	@APP_POD=$$(kubectl get pods | grep $(DEPLOYMENT_NAME) | head -n 1 | awk '{print $$1}'); \
	kubectl port-forward $$APP_POD $(APP_PORT):80 &

## Port-Forwarding beenden
stop-port-forwarding: ## Beendet das Port-Forwarding
	@echo "Stopping all port-forwarding processes..."
	@pkill -f "kubectl port-forward" || true

## Status überprüfen
check-status: ## Überprüft den Status von Longhorn und dem Deployment
	@echo "Checking Longhorn Pods..."
	@kubectl -n $(NAMESPACE) get pods
	@echo "Checking PVC and PV..."
	@kubectl get pvc $(PVC_NAME)
	@kubectl get pv | grep $(VOLUME_NAME)
	@echo "Checking Deployment and Service..."
	@kubectl get deployment $(DEPLOYMENT_NAME)
	@kubectl get svc $(DEPLOYMENT_NAME)-service
	@echo "All checks passed."

## Anwendungsverfügbarkeit überprüfen
check-app-availability: ## Prüft die Verfügbarkeit der Testanwendung
	@echo "Checking application availability at http://localhost:$(APP_PORT)"
	@MAX_RETRIES=10; \
	RETRY_COUNT=0; \
	while ! curl -s -o /dev/null -w "%{http_code}" http://localhost:$(APP_PORT) | grep -q "200"; do \
		if [ $$RETRY_COUNT -eq $$MAX_RETRIES ]; then \
			echo "Application not available after $$MAX_RETRIES retries."; \
			exit 1; \
		fi; \
		echo "Application not yet available. Retrying..."; \
		sleep 5; \
		RETRY_COUNT=$$((RETRY_COUNT+1)); \
	done
	@echo "Application is available at http://localhost:$(APP_PORT)"

## Full Setup
full-setup: install-longhorn create-volume create-pvc create-deployment create-service expose-dashboard expose-app check-status check-app-availability ## Führt den kompletten Setup-Prozess durch
	@echo "Full setup completed successfully."
