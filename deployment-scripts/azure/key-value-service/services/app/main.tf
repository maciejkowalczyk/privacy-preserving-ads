# Portions Copyright (c) Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "azurerm_kubernetes_cluster" "credentials" {
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name

  depends_on = [
    var.aks_cluster_name
  ]
}

provider "helm" {
  debug = true
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
  }
}

locals {
  env_vars = flatten([
    for container in var.containers : [
      for key, value in container.runtime_flags : {
        name  = "services.${container.name}.env.${key}"
        value = value
      }
    ]
  ])
}

resource "helm_release" "kv_services" {
  name      = "kv-services"
  namespace = var.kubernetes_namespace
  chart     = "${path.module}/helm"
  timeout   = 900

  values = [
    "${file("${path.module}/helm/kv_services.yaml")}"
  ]

  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.image"
      value = set.value.image
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.ccePolicy"
      value = set.value.ccepolicy
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.nodeSelector.container-image"
      value = set.value.name
    }
  }
  dynamic "set" {
    for_each = var.global_runtime_flags
    content {
      name  = "env.${set.key}"
      value = set.value
    }
  }

  dynamic "set" {
    for_each = tomap({
      for item in local.env_vars : "${item.name}" => item
    })
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.containerPorts[0].port"
      value = coalesce(lookup(set.value["runtime_flags"], "PORT", ""))
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.healthCheck.port"
      value = coalesce(lookup(set.value["runtime_flags"], "HEALTHCHECK_PORT", ""))
    }
  }

  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.resources.requests.cpu"
      value = set.value.resources.requests.cpu
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.resources.requests.memory"
      value = set.value.resources.requests.memory
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.limits.requests.cpu"
      value = set.value.resources.limits.cpu
    }
  }
  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.resources.limits.memory"
      value = set.value.resources.limits.memory
    }
  }

  dynamic "set" {
    for_each = var.containers
    content {
      name  = "services.${set.value.name}.replicas"
      value = set.value.replicas
    }
  }

  set {
    name  = "virtualNodeIdentity"
    value = var.virtual_node_identity_id
  }

  set {
    name  = "storageAccount.resourceGroup"
    value = var.resource_group_name
  }

  set {
    name  = "storageAccount.name"
    value = var.storage_account_name
  }

  set {
    name  = "storageAccount.fileShare"
    value = var.file_share_name
  }

  set {
    name  = "storageAccount.accessKey"
    value = var.storage_account_access_key
  }
}