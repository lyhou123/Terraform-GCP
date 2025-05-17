provider "google" {
  credentials = file("${path.module}/gcp-creds.json")
  project     = var.project_id
  region      = var.region
}


# Reserve a static external IP
resource "google_compute_address" "static_ip" {
  name   = "static-ip-3"
  region = var.region
}

# Create a firewall rule to allow SSH and HTTP traffic
resource "google_compute_instance" "vm_instance" {
  name         = "my-terraform-test" # replace with your desired instance name or customize it
  machine_type = "e2-micro"     # replace with your desired machine type
  # machine_type = "f1-micro"   # replace with your desired machine type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts" # replace with your desired image
      # image = "ubuntu-os-cloud/ubuntu-2204-jammy-v20230912" # replace with your desired image
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # Add startup script to install Apache and set password for 'ubuntu' user
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt update
    apt install -y apache2

    # Set a password for the 'ubuntu' user
    echo 'ubuntu:YourSecurePassword' | chpasswd   

    # Enable password authentication in SSH config
    sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

    # Restart SSH service
    systemctl restart sshd
  EOT
  # replace your actual password with 'YourSecurePassword'

  metadata = {
    enable-oslogin = "FALSE"  # disables OS Login so you can use password auth
  }

  tags = ["http-server"]
}

resource "google_compute_firewall" "default" {
  name    = "allow-http-3"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "22"] # Allow HTTP and SSH traffic
  }

  source_ranges = ["0.0.0.0/0"] # Allow traffic from anywhere
  target_tags   = ["http-server"]
}
