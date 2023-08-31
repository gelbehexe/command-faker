<?php

namespace Pj\CommandFaker\Tests\Feature;

use Illuminate\Testing\PendingCommand;
use Orchestra\Testbench\Concerns\WithWorkbench;
use Orchestra\Testbench\TestCase;
use Symfony\Component\Console\Exception\CommandNotFoundException;

/**
 * @coversNothing
 *
 * This is not testable the default way because dynamically registering commands in ArtisanStarting event
 * is only possible when arguments are coming form command line
 * there is no other way to get the command by getFirstArgument
 *
 * @backupGlobals enabled
 */
class CommandLineTest extends TestCase
{
    use WithWorkbench;

    private bool|array|null $oldArgv = false;

    private ?int $oldArgc = 0;

    protected function setUp(): void
    {
        parent::setUp();
        commandFaker()->registerCommand('banana');
        if (isset($_SERVER['argv'])) {
            $this->oldArgv = $_SERVER['argv'];
            $this->oldArgc = $_SERVER['argc'];
        }

    }

    protected function tearDown(): void
    {
        if ($this->oldArgv !== false) {
            $_SERVER['argc'] = $this->oldArgc;
            $_SERVER['argv'] = $this->oldArgv;

        }
        parent::tearDown();
    }

    /**
     * A basic feature test example.
     */
    public function testFakedCommand(): void
    {

        $this->makeArtisan('banana', ['--my-example-argument-one'])->assertExitCode(0);
    }

    private function makeArtisan(string $command, array $args = []): PendingCommand|int
    {
        $_SERVER['argv'] = ['dummy', $command, ...$args];
        $_SERVER['argc'] = count($_SERVER['argv']);

        return $this->artisan($command, $args);
    }

    public function testExistingCommand(): void
    {
        $this->makeArtisan('about')->assertExitCode(0);
    }

    public function testNonExistingCommand(): void
    {
        static::expectException(CommandNotFoundException::class);
        $this->makeArtisan('non-existing-command')->run();
    }
}
