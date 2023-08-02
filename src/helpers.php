<?php

if (!function_exists('commandFakerShouldIgnoreErrors')) {
    function commandFakerShouldIgnoreErrors(): bool
    {
        return config('command-faker.ignore-errors') ??
            app()->isProduction();
    }

}

if (!function_exists('commandFaker')) {
    function commandFaker(): \Pj\CommandFaker\Support\FakeCommandRepository
    {
        return app(\Pj\CommandFaker\Support\FakeCommandRepository::class);
    }

}
