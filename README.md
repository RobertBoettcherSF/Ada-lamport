# Ada-lamport

Ada implementation of **Lamport's Bakery Algorithm** - a classic mutual exclusion algorithm for concurrent systems.

## Overview

Lamport's Bakery Algorithm is a distributed mutual exclusion algorithm that ensures:
- **Mutual Exclusion**: Only one thread can be in the critical section at a time
- **No Deadlock**: Threads will eventually enter the critical section
- **FIFO Ordering**: Threads enter in the order they request the lock (approximately)

The algorithm uses a "ticket number" system where threads take a number before entering the critical section, similar to a bakery.

## Project Structure

```
Ada-lamport/
├── bakery.adb          # Main implementation
├── bakery.ads          # Specification
├── bakery.gpr          # GNAT project file
├── Makefile            # Build automation
├── README.md           # This file
└── tests/
    ├── bakery_tests.adb    # Comprehensive test suite
    └── bakery_tests.gpr    # Test project file
```

## Quick Start

### Prerequisites

- **GNAT Ada Compiler** (part of GCC)
  - Ubuntu/Debian: `sudo apt-get install gnat`
  - Fedora: `sudo dnf install gcc-gnat`
  - macOS: `brew install gnat`
  - Windows: Download from [AdaCore](https://www.adacore.com/download)

### Building

```bash
# Clone the repository
git clone https://github.com/RobertBoettcherSF/Ada-lamport.git
cd Ada-lamport

# Build the main program
make build

# Or manually:
mkdir -p obj bin
gnatmake -P bakery.gpr
```

### Running

```bash
# Run the main bakery demonstration
make run

# Or manually:
./bin/bakery
```

### Testing

```bash
# Run all tests
make test

# Or manually:
mkdir -p obj bin
gnatmake -P tests/bakery_tests.gpr
./bin/bakery_tests
```

## Implementation Details

### Algorithm Steps

1. **Doorway Phase**: Thread sets `Entering[Id] = True` and gets the maximum ticket number
2. **Ticket Assignment**: Thread assigns itself `Number[Id] = Max_Num + 1` and sets `Entering[Id] = False`
3. **Waiting Phase**: Thread waits until:
   - All other threads have finished the doorway phase (`Entering[J] = False`)
   - All threads with lower ticket numbers have finished (`Number[J] = 0`)
   - For threads with the same ticket number, the one with lower ID goes first

### Key Features

- **Atomic Components**: Uses `pragma Atomic_Components` for thread-safe array access
- **Busy Wait with Yield**: Uses `delay 0.0001` to prevent 100% CPU usage
- **Natural Number Tickets**: Uses Ada's `Natural` type which can handle very large numbers

## Test Suite

The test suite (`tests/bakery_tests.adb`) contains **15 comprehensive tests** that validate:

### Basic Functionality (Tests 1-3)
1. **Single thread lock/unlock** - Verifies basic lock acquisition and release
2. **Unique ticket numbers** - Ensures threads get unique, increasing ticket numbers
3. **Mutual exclusion** - Confirms only one thread can be in critical section at a time

### Edge Cases (Tests 4-8)
4. **Reentrant lock** - Verifies lock is NOT reentrant (expected to fail - correct behavior)
5. **Ticket overflow** - Tests handling of very large ticket numbers
6. **Tie breaking by ID** - Validates that lower thread IDs get priority when tickets are equal
7. **Entering flag** - Ensures the Entering flag prevents race conditions in the doorway
8. **Unlock resets ticket** - Confirms unlock sets ticket number to 0

### Robustness Tests (Tests 9-13)
9. **Multiple lock cycles** - Tests repeated lock/unlock operations
10. **No starvation** - Verifies all threads can eventually acquire the lock
11. **FIFO ordering** - Checks that lock acquisition follows request order
12. **Critical section protection** - Validates shared data integrity
13. **Max threads** - Tests with maximum configured threads

### Error Handling (Tests 14-15)
14. **Unlock without lock** - Ensures unlocking without prior lock is safe
15. **Concurrent lock requests** - Tests simultaneous lock requests

### Test Output

```
========================================
BAKERY ALGORITHM TEST SUITE
========================================

Test  1: Single thread lock/unlock ... PASS
Test  2: Unique increasing ticket numbers ... PASS
Test  3: Mutual exclusion with concurrent threads ... PASS
Test  4: Reentrant lock (expected to fail - not reentrant) ... PASS
Test  5: Ticket number overflow handling ... PASS
Test  6: Tie breaking by thread ID ... PASS
Test  7: Entering flag prevents doorway race ... PASS
Test  8: Unlock resets ticket to 0 ... PASS
Test  9: Multiple lock/unlock cycles ... PASS
Test 10: No starvation - all threads can acquire lock ... PASS
Test 11: FIFO ordering of lock acquisition ... PASS
Test 12: Critical section protects shared data ... PASS
Test 13: Lock with maximum threads ... PASS
Test 14: Unlock without prior lock ... PASS
Test 15: Concurrent lock requests ... PASS

========================================
Test Summary:
  Total:   15
  Passed:  15
  Failed:   0
========================================
ALL TESTS PASSED!
```

## Usage Example

```ada
with Bakery;

procedure My_Program is
   task type Worker (Id : Integer);
   task body Worker is
   begin
      Bakery.Lock (Id);
      -- Critical section
      Bakery.Unlock (Id);
   end Worker;
begin
   -- Create and start workers
   null;
end My_Program;
```

## Algorithm Analysis

### Time Complexity
- **Lock**: O(N) where N is the number of threads
- **Unlock**: O(1)

### Space Complexity
- O(N) for the Entering and Number arrays

### Advantages
- Simple and easy to understand
- No central authority needed
- Works on most architectures
- Provides FIFO ordering

### Disadvantages
- Busy waiting (spins in waiting phase)
- O(N) space complexity
- Not suitable for systems with many threads

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Lamport, L. (1974). "A New Solution of Dijkstra's Concurrent Programming Problem".](https://lamport.azurewebsites.net/pubs/bakery.pdf)
- [Wikipedia: Lamport's Bakery Algorithm](https://en.wikipedia.org/wiki/Lamport%27s_bakery_algorithm)
