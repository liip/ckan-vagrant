Vagrant setup of 

## ## Requirements

- Vagrant >= 1.2
- Virtualbox

## Digitalocean

### Install the required Vagrant plugins

    vagrant plugin install vagrant-digitalocean
    vagrant plugin install vagrant-omnibus

### Setup the Digitalocean keys

Copy `digitalocean.json.dist` to `digitalocean.json` and add the client id and the API key

### Fire it up

Uncomment the relevant lines in the Vagrant file.

    vagrant up --provider=digital_ocean

## Switching providers

"Vagrant currently allows each machine to be brought up with only a single provider at a time". That means you cannot do `vagrant up` with `virtualbox` and then with`digitalocean`. Quite a simple fix for that is to rename the `.vagrant` folder to e.g. `.vagrant.digitalocean`. Running `vagrant up` after that will create a new folder that contains the `virtualbox` specific config and you can switch by renaming the folders.
