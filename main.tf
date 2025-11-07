###########################################
# Terraform OpenStack Template (Safe)
# ---------------------------------------
# Template ini digunakan untuk membuat:
# - 1 Network + Subnet
# - 1 Router yang terhubung ke Public Network
# - 3 VM (loop otomatis)
# - Floating IP untuk tiap VM
# ---------------------------------------
###########################################

terraform {
  required_version = ">= 0.14.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

###########################################
# Provider Configuration
# ---------------------------------------
# Data autentikasi diambil dari file `clouds.yml`
# (bukan ditulis langsung di sini).
# Pastikan environment variable `OS_CLOUD` di-set ke "openstack"
###########################################
provider "openstack" {
  cloud  = "openstack"
  region = "<your_region>" # contoh: banten-1, jakarta-2, dsb
}

###########################################
# Network & Subnet
# ---------------------------------------
# Membuat private network dan subnet internal
# untuk VM.
###########################################
resource "openstack_networking_network_v2" "project_net" {
  name = "<your_project_name>-network"
}

resource "openstack_networking_subnet_v2" "project_subnet" {
  name       = "<your_project_name>-subnet"
  network_id = openstack_networking_network_v2.project_net.id
  cidr       = "10.10.0.0/24" # ubah sesuai kebutuhan jaringan kamu
  ip_version = 4
  gateway_ip = "10.10.0.1"
}

###########################################
# Router
# ---------------------------------------
# Router menghubungkan subnet internal
# ke jaringan publik (internet).
###########################################
resource "openstack_networking_router_v2" "project_router" {
  name                = "<your_project_name>-router"
  # Ganti dengan ID atau nama public network di environment kamu
  external_network_id = "PUBLIC_NETWORK_ID"
}

resource "openstack_networking_router_interface_v2" "project_router_if" {
  router_id = openstack_networking_router_v2.project_router.id
  subnet_id = openstack_networking_subnet_v2.project_subnet.id
}

###########################################
# Compute Instances (VM)
# ---------------------------------------
# Membuat 3 VM menggunakan loop (count).
# Nama VM diambil dari daftar di `local.vm_names`
###########################################
locals {
  vm_names = ["<your_project_name>-1", "<your_project_name>-2", "<your_project_name>-3"]
}

resource "openstack_compute_instance_v2" "project_vms" {
  count           = length(local.vm_names)
  name            = local.vm_names[count.index]
  image_name      = "<your_image_name>"  # contoh: Ubuntu 22.04 LTS
  flavor_name     = "<your_flavor_name>" # contoh: SS2.1
  key_pair        = "<your_keypair>"     # nama keypair yang sudah ada di OpenStack
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.project_net.id
  }
}

###########################################
# Floating IP
# ---------------------------------------
# Membuat Floating IP dari pool publik dan
# mengasosiasikannya ke masing-masing VM.
###########################################
resource "openstack_networking_floatingip_v2" "project_fip" {
  count = length(local.vm_names)
  pool  = "<your_public_network_pool>" # contoh: Public_Network
}

resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  count       = length(local.vm_names)
  floating_ip = openstack_networking_floatingip_v2.project_fip[count.index].address
  instance_id = openstack_compute_instance_v2.project_vms[count.index].id
}

###########################################
# Output
# ---------------------------------------
# Menampilkan hasil IP publik untuk tiap VM
###########################################
output "instance_ips" {
  value = {
    for idx, vm in openstack_compute_instance_v2.project_vms :
    vm.name => openstack_networking_floatingip_v2.project_fip[idx].address
  }
}
