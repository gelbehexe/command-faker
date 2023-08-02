# Setup a simple php cli docker machine
*Gist to setup a simple php cli docker machine with latest php version* 

## Usage
### Installation:

```shell
# cd <your project>

git clone git@gist.github.com:0e9a475e3882b3868ef28dc07cf55d05.git docker
cd docker

mkdir tmp

# optional if you do not want the files to be part of the project
echo "*" > .gitignore

# allow execution for run helper script
chmod +x ./run.sh

# optional: set your uid and guid to be used in docker environment with "gosu" (linux/mac)
# (make sure to be in a separate folder to avoid to override your project .env file)
echo -e "GOSU_UID=$(id -u)\nGOSU_GID=$(id -g)" > .env
```

## build
```shell
# cd <your project>
docker/run.sh build
```


### Go to docker shell
```shell
# cd <your project>
docker/run.sh shell
```

### Go to docker root shell
```shell
# cd <your project>
docker/run.sh root-shell
```

### Rebuild
```shell
# cd <your project>
docker/run.sh rebuild
```


### Examples

#### Run unit tests
```shell
# cd <your project>
docker/run.sh php vendor/bin/phpunit
```

#### Use composer
```shell
# cd <your project>
docker/run.sh php composer
```

#### Output a list of modules
```shell
# cd <your project>
docker/run.sh php -m > docker/tmp/php_modules.txt
```

#### Check uncommitted files
```shell
# cd <your project>
git status --untracked-files --short --porcelain  | sed -r 's/^...//g' | xargs bash docker/run.sh -T phpcs -v
```
