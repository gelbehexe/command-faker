<?php

namespace Pj\CommandFaker;

use Illuminate\Console\Events\ArtisanStarting;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Pj\CommandFaker\Support\FakeCommandRepository;
use Symfony\Component\Console\ConsoleEvents;
use Symfony\Component\Console\Event\ConsoleErrorEvent;
use Symfony\Component\Console\Exception\CommandNotFoundException;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\EventDispatcher\EventDispatcherInterface;

class CommandFakerServiceProvider extends ServiceProvider
{
    /** @noinspection PhpUnusedParameterInspection */
    public function register(): void
    {
        $this->app->singleton(FakeCommandRepository::class);

        if (! $this->app->runningInConsole() || $this->app->runningUnitTests()) {
            return;
        }

        Event::listen(ArtisanStarting::class, function (ArtisanStarting $_) {
            try {
                $kernel = resolve(Kernel::class);
                $reflection = new \ReflectionClass(get_class($kernel));
                /** @var null|EventDispatcherInterface $symfonyDispatcher */
                $symfonyDispatcher = $reflection->getProperty('symfonyDispatcher')->getValue($kernel);
                $symfonyDispatcher?->addListener(ConsoleEvents::ERROR, function (ConsoleErrorEvent $event) {
                    if (! ($event->getError() instanceof CommandNotFoundException)) {
                        return;
                    }
                    $command = $event->getInput()->getFirstArgument();
                    if (commandFaker()->matches($command)) {
                        $event->getOutput()->writeln('This command is not implemented, but was faked by "CommandFaker"', OutputInterface::VERBOSITY_VERBOSE);
                        $event->setExitCode(0);
                    }
                });
            } catch (\Throwable $exception) {
                if (commandFakerShouldIgnoreErrors()) {
                    return;
                }

                throw $exception;
            }
        });
    }
}
