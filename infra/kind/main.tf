# infra/kind/main.tf

resource "kind_cluster" "staging_cluster" {
  name            = "staging-cluster"
  wait_for_ready  = true # Espera o cluster estar pronto

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4" # Use a API version compatível com sua versão do Kind

    # CORREÇÃO: Use 'node' (singular) para cada definição de nó
    node {
      role = "control-plane"
      # (Opcional) Mapear porta do Ingress para o host
      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\""
      ]
      extra_port_mappings {
         container_port = 80
         host_port      = 8080 # Mapeia porta 80 do container (Ingress) para 8080 do host
         protocol       = "TCP"
      }
      extra_port_mappings {
         container_port = 443
         host_port      = 8443 # Mapeia porta 443 do container (Ingress) para 8443 do host
         protocol       = "TCP"
      }
    }

    # CORREÇÃO: Use 'node' (singular) para cada definição de nó
    node {
      role = "worker"
    }
    # Adicione mais blocos 'node' (singular) se precisar de mais workers
    # node {
    #   role = "worker"
    # }
  }
}


