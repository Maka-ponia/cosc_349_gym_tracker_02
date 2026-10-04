Vagrant.configure("2") do |config|

  config.vm.boot_timeout = 900

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus = 1
  end

  config.vm.define "frontend" do |frontend|
    frontend.vm.box = "ubuntu/jammy64"
    frontend.vm.hostname = "frontend"
    frontend.vm.network "private_network", ip: "192.168.56.10"

    frontend.vm.provision "shell", path: "scripts/frontend.sh"
  end

  config.vm.define "backend" do |backend|
    backend.vm.box = "ubuntu/jammy64"
    backend.vm.hostname = "backend"
    backend.vm.network "private_network", ip: "192.168.56.11"

    backend.vm.provision "shell", path: "scripts/backend.sh"
  end

  config.vm.define "database" do |database|
    database.vm.box = "ubuntu/jammy64"
    database.vm.hostname = "database"
    database.vm.network "private_network", ip: "192.168.56.12"

    database.vm.provision "shell", path: "scripts/database.sh"
  end

end