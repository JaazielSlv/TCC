# frozen_string_literal: true

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.synced_folder ".", "/vagrant"

  # Topologia:
  # Rede externa (192.168.56.0/24): cliente_classico_1, cliente_malicioso, roteador(wan)
  # Rede interna (192.168.57.0/24): cliente_classico_2, servidor, roteador(lan)
  vm_specs = {
    "cliente_classico_1" => {
      hostname: "cliente-classico-1",
      ram: 1024,
      cpus: 1,
      nics: [{ ip: "192.168.56.11", netmask: "255.255.255.0" }]
    },
    "cliente_malicioso" => {
      hostname: "cliente-malicioso",
      ram: 1024,
      cpus: 1,
      nics: [{ ip: "192.168.56.66", netmask: "255.255.255.0" }]
    },
    "roteador" => {
      hostname: "roteador",
      ram: 1536,
      cpus: 2,
      nics: [
        { ip: "192.168.56.254", netmask: "255.255.255.0" },
        { ip: "192.168.57.254", netmask: "255.255.255.0" }
      ]
    },
    "cliente_classico_2" => {
      hostname: "cliente-classico-2",
      ram: 1024,
      cpus: 1,
      nics: [{ ip: "192.168.57.12", netmask: "255.255.255.0" }]
    },
    "servidor" => {
      hostname: "servidor",
      ram: 1536,
      cpus: 1,
      nics: [{ ip: "192.168.57.20", netmask: "255.255.255.0" }]
    }
  }

  vm_specs.each do |name, spec|
    config.vm.define name do |vm|
      vm.vm.hostname = spec[:hostname]

      spec[:nics].each do |nic|
        vm.vm.network "private_network", ip: nic[:ip], netmask: nic[:netmask]
      end

      vm.vm.provider "virtualbox" do |vb|
        vb.name = "tcc-#{name}"
        vb.memory = spec[:ram]
        vb.cpus = spec[:cpus]
      end

      vm.vm.boot_timeout = 0
    end
  end

  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.compatibility_mode = "2.0"

    ansible.extra_vars = {
      ext_net_cidr: "192.168.56.0/24",
      int_net_cidr: "192.168.57.0/24",
      router_wan_ip: "192.168.56.254",
      router_lan_ip: "192.168.57.254"
    }
  end
end
