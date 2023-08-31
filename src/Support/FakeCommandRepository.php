<?php

namespace Pj\CommandFaker\Support;

class FakeCommandRepository
{
    protected array $faked_commands = [];

    public function registerCommand(string ...$command): static
    {
        $this->faked_commands = array_unique([
            ...$this->faked_commands,
            ...$command,
        ]);

        return $this;
    }

    public function matches(string $command): bool
    {
        foreach ($this->faked_commands as $faked_command) {
            if ($this->isCommandMatching($command, $faked_command)) {
                return true;
            }
        }

        return false;
    }

    protected function isCommandMatching(string $command, string $registeredCommand): bool
    {
        if (blank($command)) {
            return false;
        }
        if ($command === $registeredCommand) {
            return true;
        }

        if (! str_contains($registeredCommand, '*')) {
            return false;
        }

        $clean_wildcard = preg_replace('/\*{2,}/', '*', $registeredCommand);

        $parts = explode('*', $clean_wildcard);

        $part = array_shift($parts);
        if (! str_starts_with(haystack: $command, needle: $part)) {
            return false;
        }

        if (! count($parts)) {
            return true;
        }

        $command = substr($command, strlen($part));

        $part = array_pop($parts);

        if (! str_ends_with(haystack: $command, needle: $part)) {
            return false;
        }

        if (! count($parts)) {
            return true;
        }

        $command = substr($command, 0, strlen($command) - strlen($part));

        foreach ($parts as $part) {
            if (($pos = strpos($command, $part)) === false) {
                return false;
            }
            $command = substr($command, $pos + strlen($part));
        }

        return true;
    }
}
