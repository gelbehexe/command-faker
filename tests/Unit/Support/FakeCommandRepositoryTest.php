<?php

namespace Pj\CommandFaker\Tests\Unit\Support;

use Mockery\MockInterface;
use Orchestra\Testbench\TestCase;
use Pj\CommandFaker\Support\FakeCommandRepository;

/**
 * @covers \Pj\CommandFaker\Support\FakeCommandRepository
 */
class FakeCommandRepositoryTest extends TestCase
{
    protected function setUp(): void
    {
        if (function_exists('opcache_reset')) {
            opcache_reset();
        }
        parent::setUp();
    }

    public static function isCommandMatchingDataProvider(): array
    {
        return [
            // command, registeredCommand, expected, description
            ['', 'myVerySmallCommand', false, 'Empty command does never match'],
            ['myVerySmallCommand', 'myVerySmallCommand', true, 'Does equality matches'],
            ['myVerySmallCommand', 'myOthersVerySmallCommand', false, 'Does non-equality not match'],
            ['myVerySmallCommand', 'myOthers*rySmallCommand', false, 'Non matching wildcard'],
            ['myVerySmallCommand', 'myVerySmall*', true, 'Starts with matches'],
            ['myVerySmallCommand', '*SmallCommand', true, 'Ends with matches'],
            ['myVerySmallCommand', 'my*SmallCommand', true, 'Wildcard in the middle matches'],
            ['myVerySmallCommand', 'my*Sma*Command', true, 'Two wildcards in the middle matches'],
            ['myFirstVerySmallCommand', 'myVerySmall*', false, 'Starts with does not match'],
            ['myVerySmallCommand', '*BigCommand', false, 'Ends with does not match'],
            ['myVerySmallCommand', 'my*BigCommand', false, 'Wildcard in the middle does not match'],
            ['myVerySmallCommand', 'my*Bi*Command', false, 'Two wildcards in the middle does not match'],
            ['myVerySmallCommand', 'myVerySmallCommand1', false, 'Registered command starting with same string but without wildcard should fail'],
        ];
    }

    /**
     * @return void
     *
     * @dataProvider isCommandMatchingDataProvider
     */
    public function testIsCommandMatching($command, $registeredCommand, $expected, $description)
    {
        /** @var mixed $mock - disable ide warning about protected member */
        $mock = \Mockery::mock(FakeCommandRepository::class);

        $result = $mock->isCommandMatching($command, $registeredCommand);

        $this->assertEquals($expected, $result, $description);
    }

    public static function hasFakedCommandsDataProvider(): array
    {
        return [
            // [$registeredCommands, $expectedResult, $comment]
            [[], false, 'No commands registered should return false'],
            [['command1'], true, 'One Command registered should return true'],
            [['command1', 'command2'], true, 'Two Commands registered should return true'],
        ];
    }

    /**
     * @dataProvider hasFakedCommandsDataProvider
     */
    public function testHasFakedCommands(
        array $registeredCommands,
        bool $expectedResult,
        string $comment,
    ): void {

        $mock = \Mockery::mock(FakeCommandRepository::class, function (MockInterface $mock) use ($registeredCommands) {
            $mock
                ->makePartial()
                ->shouldReceive('getFakedCommands')
                ->withNoArgs()
                ->once()
                ->andReturn($registeredCommands);
        });

        $result = $mock->hasFakedCommands();

        $this->assertSame($expectedResult, $result, $comment);
    }

    public static function matchesDataProvider(): array
    {
        $registeredCommands = ['first', 'second', 'third'];

        return [
            // $registeredCommands, $results, $expectedResult, $queryCount, $comment
            [$registeredCommands, [false, false, false], false, 3, 'No command matching does not match'],
            [$registeredCommands, [false, false, true], true, 3, 'Third command matching does not match'],
            [$registeredCommands, [false, true, true], true, 2, 'Second + third command matching matches'],
            [$registeredCommands, [true, true, true], true, 1, 'All commands matching matches'],
        ];
    }

    /**
     * @return void
     *
     * @dataProvider matchesDataProvider
     */
    public function testMatches(
        array $registeredCommands,
        array $results,
        bool $expectedResult,
        int $queryCount,
        string $comment
    ) {
        $something = 'something';
        $mock = \Mockery::mock(
            FakeCommandRepository::class,
            function (MockInterface $mock) use ($registeredCommands, $results, $something, $queryCount) {
                $mock
                    ->makePartial()
                    ->shouldAllowMockingProtectedMethods();
                $timesArray = array_slice([...array_fill(0, $queryCount, 1), ...array_fill(0, count($registeredCommands), 0)], 0, count($registeredCommands));
                reset($results);
                foreach ($registeredCommands as $registeredCommand) {
                    $mock
                        ->shouldReceive('isCommandMatching')
                        ->times(current($timesArray))
                        ->with($something, $registeredCommand)
                        ->andReturn(current($results));

                    next($results);
                    next($timesArray);
                }

                $mock
                    ->shouldReceive('getFakedCommands')
                    ->once()
                    ->withNoArgs()
                    ->andReturn($registeredCommands);
            }
        );

        $result = $mock->matches($something);

        static::assertEquals($expectedResult, $result, $comment);

    }

    public static function registerAndGetCommandsDataProvider(): array
    {
        return [
            // $commandsToRegister, $expectedResult, $comment
            [['first', 'second', 'last'], ['first', 'second', 'last'], 'Simple register test'],
            [['first', 'second', 'last', 'first'], ['first', 'second', 'last'], 'Eliminates duplicates'],
        ];
    }

    /**
     * @return void
     *
     * @throws \ReflectionException
     *
     * @dataProvider registerAndGetCommandsDataProvider
     */
    public function testRegisterAndGetCommands(
        array $commandsToRegister,
        array $expectedResult,
        string $comment
    ) {

        $reflectionObject = new \ReflectionClass(FakeCommandRepository::class);
        $mock = $reflectionObject->newInstanceWithoutConstructor();

        foreach ($commandsToRegister as $item) {
            $mock->registerCommand($item);
        }

        $reflectionMethod = new \ReflectionMethod($mock, 'getFakedCommands');
        $result = $reflectionMethod->invoke($mock);

        static::assertEqualsCanonicalizing($result, $expectedResult, $comment);
    }
}
