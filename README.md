# openstackctx: Openstack project switcher

`openstackctx` helps you to switch between different Openstack projects
in your shell.
It keeps your environment variables in sync with the activated Openstack project.

## Usage
```
(my-openstack-project-2) $ env | grep OS_PROJECT_ID
OS_PROJECT_ID=my-project-2-id

(my-openstack-project-2) $ openstackctx
Use the arrow keys to navigate: ↓ ↑ → ←
? Select Openstack context:
  ▸ my-openstack-project-1
    my-openstack-project-2

(my-openstack-project-1) $ env | grep OS_PROJECT_ID
OS_PROJECT_ID=my-project-2-id
... 
```

## Installation

Download latest version from [Releases](https://github.com/Hugoch/openstackctx/releases) according to 
your architecture.

```
$ tar xvf openstackctx-v0.1-darwin.tar.gz
$ cd openstackctx-v0.1-darwin
$ mv openstackctxcli /usr/local/bin
$ chmod +x /usr/local/bin/openstackctxcli
$ mv openstack-ps1.sh /usr/local/bin
$ chmod +x /usr/local/bin/openstack-ps1.sh
```
then add to your `.zshrc` or `.bashrc`
```
source /usr/local/bin/openstack-ps1.sh
PROMPT='$(openstack_ps1)'$PROMPT
```


## Configuration
Create `~/.openstack/config` and add your configurations.
```
current_context: my-openstack-project-1
contexts:
- name: my-openstack-project-1
  os_project_domain_name: xxx
  os_user_domain_name: xxx
  os_project_id: xxx
  os_username: xxx
  os_password: xxx
  os_auth_url: xxx
  os_region_name: xxx
- name: my-openstack-project-2
  ...
```