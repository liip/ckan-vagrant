Vagrant setup with CKAN 2.2 installed.

## Requirements

- Vagrant >= 1.2
- Virtualbox

## Virtualbox startup

    vagrant up

Add the Vagrant box's IP address to your hosts file:

    172.94.43.196   ckan.lo

## Digitalocean

### Install the required Vagrant plugins

    vagrant plugin install vagrant-digitalocean
    vagrant plugin install vagrant-omnibus

### Setup the Digitalocean keys

Copy `digitalocean.json.dist` to `digitalocean.json` and add the client id and the API key
Uncomment the relevant lines in the Vagrantfile.

### Fire it up

    vagrant up --provider=digital_ocean

## Switching providers

"Vagrant currently allows each machine to be brought up with only a single provider at a time". That means you cannot do `vagrant up` with `virtualbox` and then with`digitalocean`. Quite a simple fix for that is to rename the `.vagrant` folder to e.g. `.vagrant.digitalocean`. Running `vagrant up` after that will create a new folder that contains the `virtualbox` specific config and you can switch by renaming the folders.
