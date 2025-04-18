#!/bin/bash

# Script para configurar e iniciar o ambiente de staging local completo.
# Executar a partir da raiz do projeto: ./run_all.sh

# Parar em caso de erro
set -e

echo "#############################################"
echo "### INICIANDO SETUP COMPLETO DO AMBIENTE  ###"
echo "#############################################"
echo ""

# --- Limpeza Inicial ---
echo ">>> [FASE 1/8] Limpeza Inicial..."
echo "Parando e removendo containers/redes/volumes Docker Compose antigos..."
docker compose -f docker-compose-jenkins.yml down -v --remove-orphans || true
docker compose -f sonarqube/docker-compose.yaml down -v --remove-orphans || true
docker compose -f logging/docker-compose.elk.yaml down -v --remove-orphans || true
docker compose -f monitoring/docker-compose.yaml down -v --remove-orphans || true
docker compose -f docker-compose-localstack.yml down -v --remove-orphans || true
echo "Deletando cluster Kind antigo (se existir)..."
kind delete cluster --name staging-cluster || true
echo "Removendo redes Docker manuais (se existirem)..."
docker network rm devops-net || true
docker network rm kind || true # Kind geralmente recria, mas limpamos por via das dúvidas
echo "Limpando Docker (prune)..."
docker system prune -af || true
# ATENÇÃO: O comando abaixo remove VOLUMES não usados. Descomente com cuidado se quiser limpeza total.
# echo "Removendo volumes Docker não usados..."
# docker volume prune -f || true
echo "Limpeza inicial concluída."
echo ""

# --- Ajustes de Sistema (Elasticsearch/SonarQube) ---
echo ">>> [FASE 2/8] Ajustando Limites do Sistema (vm.max_map_count)..."
sudo sysctl -w vm.max_map_count=262144
echo "--> Lembre-se de adicionar 'vm.max_map_count=262144' em /etc/sysctl.conf para persistência."
echo "Ajuste de limites concluído."
echo ""

# --- Rede Docker Compartilhada ---
echo ">>> [FASE 3/8] Criando Rede Docker Compartilhada 'devops-net'..."
docker network create devops-net
echo "Rede 'devops-net' criada."
echo ""

# --- Infraestrutura LocalStack ---
echo ">>> [FASE 4/8] Configurando LocalStack e Recursos AWS Simulados..."
echo "Iniciando LocalStack via Docker Compose..."
docker compose -f docker-compose-localstack.yml up -d
echo "Aguardando LocalStack iniciar (15 segundos)..."
sleep 15
echo "Provisionando recursos (S3, DynamoDB) com Terraform..."
cd infra/localstack
terraform init -upgrade
terraform apply --auto-approve
cd ../..
echo "Recursos LocalStack provisionados."
echo ""

# --- Cluster Kubernetes Kind ---
echo ">>> [FASE 5/8] Criando Cluster Kubernetes (Kind)..."
echo "Provisionando cluster Kind com Terraform..."
cd infra/kind
terraform state rm kind_cluster.staging_cluster || true # Garante que estado antigo não atrapalhe
terraform init -upgrade
terraform apply --auto-approve
cd ../..
echo "Cluster Kind criado."
echo "Configurando kubectl para usar o contexto 'kind-staging-cluster'..."
kubectl config use-context kind-staging-cluster
echo "Verificando conexão com o cluster:"
kubectl cluster-info
echo "kubectl configurado."
echo ""

# --- Nginx Ingress Controller ---
echo ">>> [FASE 6/8] Instalando Nginx Ingress Controller..."
echo "Adicionando/Atualizando repositório Helm..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update
echo "Instalando Nginx Ingress via Helm (aguardando pods ficarem prontos)..."
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --wait
echo "Verificando pods e serviço do Ingress Controller:"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
echo "Nginx Ingress Controller instalado."
echo ""

# --- Stacks Auxiliares (Sonar, ELK, Monitoramento) ---
echo ">>> [FASE 7/8] Iniciando Stacks Auxiliares (SonarQube, ELK, Monitoramento)..."
echo "Iniciando SonarQube..."
cd sonarqube
docker compose up -d
cd ..
echo "Iniciando ELK Stack..."
cd logging
docker compose -f docker-compose.elk.yaml up -d
cd ..
echo "Iniciando Stack de Monitoramento..."
cd monitoring
docker compose up -d
cd ..
echo "Stacks auxiliares iniciando em background."
echo "--> SonarQube: http://localhost:9001 (aguarde alguns minutos)"
echo "--> Kibana: http://localhost:5601 (aguarde alguns minutos)"
echo "--> Grafana: http://localhost:3000 (admin/admin)"
echo "--> Prometheus: http://localhost:9090"
echo ""

# --- Jenkins ---
echo ">>> [FASE 8/8] Iniciando Jenkins..."
docker compose -f docker-compose-jenkins.yml up -d --build
echo "Jenkins iniciando em background."
echo "Aguardando Jenkins ficar operacional (aproximadamente 90 segundos)..."
sleep 90 # Ajuste este tempo se necessário
echo "Verificando acesso básico ao Jenkins (pode levar mais tempo para estar 100% pronto)..."
curl -s -o /dev/null -I -w "%{http_code}" http://localhost:8090/login || echo "Jenkins ainda não respondeu (código curl $?). Tente acessar manualmente."
echo ""

echo "#############################################"
echo "### SETUP DO AMBIENTE CONCLUÍDO!          ###"
echo "#############################################"
echo ""
echo ">>> PRÓXIMOS PASSOS MANUAIS:"
echo "1.  **SonarQube:** Acesse http://localhost:9001, faça login (admin/admin -> nova senha), crie o projeto 'django-crm-app'."
echo "2.  **Jenkins:** Acesse http://localhost:8090, faça o setup inicial (senha, plugins, usuário)."
echo "3.  **Jenkins Config:** Configure as Credenciais ('kubeconfig-kind' com Kubeconfig editado, 'sonarqube-token' se for usar SonarQube) e o SonarQube Server (se for usar)."
echo "4.  **Jenkins Job:** Crie o Pipeline Job 'django-crm-pipeline' apontando para o repo e 'jenkins/Jenkinsfile'."
echo "5.  **Kibana:** Acesse http://localhost:5601, vá para Stack Management > Data Views e crie a Data View 'logstash-*' (pode precisar enviar um log de teste primeiro: echo '{\"message\":\"teste\"}' | nc -u -w1 localhost 5000)."
echo "6.  **Grafana:** Acesse http://localhost:3000, faça login (admin/admin) e configure as Data Sources (Prometheus: http://prometheus:9090, Loki: http://loki:3100)."
echo "7.  **EXECUTAR PIPELINE:** Após configurar o Job no Jenkins, clique em 'Construir agora'."
echo "8.  **ACESSAR APP:** Use 'kubectl port-forward -n ingress-nginx deploy/nginx-ingress-ingress-nginx-controller 8888:80' e acesse http://localhost:8888."
echo ""

