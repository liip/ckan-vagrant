# Vagrant based CKAN development environment

CKAN Version: 2.2

## Requirements

- Vagrant >= 1.6
- Virtualbox

## Virtualbox

    vagrant up

Add the Vagrant box's IP address to your hosts file:

    172.94.43.196   ckan.lo

## Docker

- [Docker](https://docker.com/) must be installed and working - **it only works on Linux hosts**

Vagrant supports Docker natively from Version 1.6 on.

You have to add permissions for the vagrant (uid 1000) user to the shared folder `ckan-vagrant`:

    setfacl -R -m u:1000:rwX .

Then you can bring the box up:

    vagrant up --provider=docker

To find out the IP Address of the box, use the container name that Vagrant prints out (in my case `ckan-vagrant_default_1409916413`) with `docker inspect`:

    docker inspect --format '{{ .NetworkSettings.IPAddress }}' ckan-vagrant_default_1409916413

See [Switching providers](## Switching providers) if work with different providers.

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
