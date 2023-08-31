[![PHP Composer](https://github.com/gelbehexe/command-faker/actions/workflows/check.yml/badge.svg)](https://github.com/gelbehexe/command-faker/actions/workflows/check.yml)

# command-faker
A faker for commands running in console to avoid errors
when running maybe as composer scripts in production
environment but installed as dev requirement.

## Installation
```shell
composer require "pj/command-faker"
```

## Usage
Register commands as you wish in your Service Provider. 

You can use the char `*` as wildcard.

_Example:_
```php
namespace App\Providers;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{

    /**
     * Register any application services.
     */
    public function register(): void
    {
        commandFaker()
            ->registerCommand('ide-helper:*','banana-command');

        if ($this->app->isLocal()) {
            $this->app->register(IdeHelperServiceProvider::class);
        }

        ...
    }

    ...
}
```
_Shell_
```shell
# will print 'OK'
pas banana-command --some-useless-arg="useless value 1" && echo "OK"

# will print 'This command is not implemented, but was faked by "CommandFaker"'
# will also print 'OK' in next line
pas banana-command -v --some-useless-arg="useless value 1" && echo "OK"
```


### Limitations
#### Does only work for commands directly called from command line:
```shell
php artisan some:command --name=sally
```
#### Does **not** work for commands called like
```php
Artisan::call('some:command',['--name' => 'sally']);
```
