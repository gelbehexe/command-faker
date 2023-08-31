<?php

namespace Pj\CommandFaker;

use Illuminate\Console\Events\ArtisanStarting;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Pj\CommandFaker\Support\FakeCommandRepository;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\ArgvInput;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class CommandFakerServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(FakeCommandRepository::class);

        if (! $this->app->runningInConsole()) {
            return;
        }

        $this->booted(function () {
            Event::listen(ArtisanStarting::class, function (ArtisanStarting $event) {
                if (! ($commandFaker = commandFaker())->hasFakedCommands()
                    || blank(($commandName = (new ArgvInput())->getFirstArgument()))
                ) {
                    return;
                }

                if (! ($commandFaker->matches($commandName))) {
                    return;
                }

                $event->artisan->add(new class($commandName) extends Command
                {
                    public function __construct(string $name = null)
                    {
                        parent::__construct($name);
                        $this->ignoreValidationErrors();
                        $this->setDescription('This command is not implemented, but was faked by "CommandFaker"');
                    }

                    protected function execute(InputInterface $input, OutputInterface $output): int
                    {
                        $output->writeln(
                            $this->getDescription(),
                            OutputInterface::VERBOSITY_VERBOSE
                        );

                        return 0;
                    }
                });

            });

        });

    }
}
