# URL of the image to use
# EXAMPLE:
# image_uri = "SLE-15-SP1-JeOS-GMC"
image_uri = "PATH-TO/SLES15-SP1-JeOS.x86_64-15.1-OpenStack-Cloud-QU1.qcow2"

# Identifier to make all your resources unique and avoid clashes with other users of this terraform project
stack_name = "MyCaaSPStack"

# CIDR of the network
network_cidr = "192.168.123.0/24"

# Number of lb nodes
lbs = 1

# Number of master nodes
masters = 1

# Number of worker nodes
workers = 2

# Name of DNS domain
dns_domain = "caasp.local"

# Username for the cluster nodes
# EXAMPLE:
username = "sles"

# Password for the cluster nodes
# EXAMPLE:
password = "linux"

# define the repositories to use
# EXAMPLE:
# repositories = {
#   repository1 = "http://example.my.repo.com/repository1/"
#   repository2 = "http://example.my.repo.com/repository2/"
# }
repositories = {}

# define the repositories to use for the loadbalancer node
# EXAMPLE:
# repositories = {
#   repository1 = "http://example.my.repo.com/repository3/"
#   repository2 = "http://example.my.repo.com/repository4/"
# }
lb_repositories = {}

# Minimum required packages. Do not remove them.
# Feel free to add more packages
packages = [
  "kernel-default",
  "-kernel-default-base"
]

lb_packages = [
  "haproxy"
]

# ssh keys to inject into all the nodes
# EXAMPLE:
# authorized_keys = [
#  "ssh-rsa <key-content>"
# ]
authorized_keys = [
  "ssh-rsa AAAAB3Nz...]

# IMPORTANT: Replace these ntp servers with ones from your infrastructure
ntp_servers = ["0.novell.pool.ntp.org", "1.novell.pool.ntp.org", "2.novell.pool.ntp.org", "3.novell.pool.ntp.org"]
