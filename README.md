[![Test Status](https://github.com/rickhull/miner_mover/actions/workflows/test.yaml/badge.svg)](https://github.com/rickhull/miner_mover/actions/workflows/test.yaml)
[![Demo Status](https://github.com/rickhull/miner_mover/actions/workflows/demo.yaml/badge.svg)](https://github.com/rickhull/miner_mover/actions/workflows/demo.yaml)

# Miner Mover

This project provides a basic  concurrency problem useful for exploring
different multitasking paradigms available in Ruby.  Fundamentally, we have a
set of *miners* and a set of *movers.*  A *miner* takes some amount of time to
mine ore, which is given to a *mover*.  When a *move*r has enough ore for a full
batch, the delivery takes some amount of time before more ore can be
loaded.

## Mining

A miner is given some depth (e.g. 1 to 100) to mine down to, which will
take an increasing amount of time with depth.  More depth provides greater ore
results as well.  Ore is gathered at each depth; either a fixed amount or
randomized, based on depth.  The amount of time spent mining each level is
independent and may be randomized.

https://github.com/rickhull/miner_mover/blob/4f2a62f6d77316e780c7c13248698d4c57bb392e/lib/miner_mover/worker.rb#L96-L104

In this case, miners are rewarded by calculating `fibonacci(depth)`, using
classic, inefficient fibonacci.
`fibonacci(35)` yields around 10M ore, while `fibonacci(30)` yields under
1M ore.

## Moving

A mover has a batch size, say 10.  As the mover accumulates ore over time,
once the batch size is reached, the mover delivers the ore to the destination.
Larger batches take longer.  The delivery time can be randomized.

https://github.com/rickhull/miner_mover/blob/4f2a62f6d77316e780c7c13248698d4c57bb392e/lib/miner_mover/worker.rb#L152-L183

The time and work spent delivering ore can be simulated three ways,
configured via `:work_type`

* `:wait` - represents waiting on IO; calls `sleep(duration)`
* `:cpu`  - busy work; calls `fibonacci(30)` until `duration` is reached
* `:instant` - useful for testing; returns immediately

# Usage

You'll want to use **Ruby 3.1+** (CRuby) to make the most of Ractors, Fibers,
and Fiber::Scheduler.

This gem can be used on JRuby and TruffleRuby, but several concurrency options
are not available: process forking, Ractors, and Fiber::Scheduler.
However, their threading performance exceeds CRuby's as they don't have a
Global VM Lock (GVL).

## Install

Right now, a gem installation only provides the Miner Mover library.
Use the **Development** process below to access all of the demonstration
scripts showing the different concurrency strategies.

`gem install miner_mover`

For Ruby 3.1+ on linux,  you'll also want:

`gem install fiber_scheduler io-event`

## Development

```
git clone https://github.com/rickhull/miner_mover
cd miner_mover
bundle config set --local with development
bundle install
```

### Rake Tasks

Try: `rake -T` to see available [Rake tasks](Rakefile)

```
$ rake -T

rake config           # Run demo/config.rb
rake demo             # Run all demos
rake fiber            # Run demo/fiber.rb
rake fiber_scheduler  # Run demo/fiber_scheduler.rb
rake jvm_demo         # Run JVM compatible demos
rake process_pipe     # Run demo/process_pipe.rb
rake process_socket   # Run demo/process_socket.rb
rake ractor           # Run demo/ractor.rb
rake serial           # Run demo/serial.rb
rake test             # Run tests
rake thread           # Run demo/thread.rb
```

Try: `rake test`

Included demonstration scripts can be executed via Rake tasks.
The following order is recommended:

* `rake config`
* `rake serial`
* `rake fiber`
* `rake fiber_scheduler`
* `rake thread`
* `rake process_pipe`
* `rake process_socket`

Try each task; there will be about 6 seconds worth of many lines of output
logging.  These rake tasks correspond to the scripts within [`demo/`](demo/).

### Satisfy `LOAD_PATH`

Rake tasks take care of `LOAD_PATH`, so the following is
**only necessary when *not* using rake tasks**:

* Execute scripts and irb sessions from the project root, e.g. `~/miner_mover`
* Use `-I lib` as a flag to `ruby` or `irb` to update `LOAD_PATH` so that
  `require 'miner_mover'` will work.
* This project does not use `require_relative`

### Exploration in `irb`

`$ irb -I lib`

```
irb(main):001:0> require 'miner_mover/worker'
=> true

irb(main):002:0> include MinerMover
=> Object

irb(main):003:0> miner = Miner.new
=>
#<MinerMover::Miner:0x00007fbee8a3a080
...

irb(main):004:0> mover = Mover.new
=>
#<MinerMover::Mover:0x00007fbee8a8a6c0
...

irb(main):005:0> miner.state
=>
{:id=>"00050720",
 :logging=>false,
 :debugging=>false,
 :timer=>10200,
 :variance=>0,
 :depth=>5,
 :partial_reward=>false}

irb(main):006:0> mover.state
=>
{:id=>"00057860",
 :logging=>false,
 :debugging=>false,
 :timer=>10456,
 :variance=>0,
 :work_type=>:cpu,
 :batch_size=>10000000,
 :batch=>0,
 :batches=>0,
 :ore_moved=>0}

irb(main):007:0> miner.mine_ore
=> 7

irb(main):008:0> mover.load_ore 7
=> 7

irb(main):009:0> miner.state
=>
{:id=>"00050720",
 :logging=>false,
 :debugging=>false,
 :timer=>28831,
 :variance=>0,
 :depth=>5,
 :partial_reward=>false}

irb(main):010:0> mover.state
=>
{:id=>"00057860",
 :logging=>false,
 :debugging=>false,
 :timer=>27959,
 :variance=>0,
 :work_type=>:cpu,
 :batch_size=>10000000,
 :batch=>7,
 :batches=>0,
 :ore_moved=>0}
```

### Included scripts

These scripts implement a full miner mover simulation using different
multitasking paradigms in Ruby.

* [`demo/serial.rb`](demo/serial.rb)
* [`demo/fiber.rb`](demo/fiber.rb)
* [`demo/fiber_scheduler.rb`](demo/fiber_scheduler.rb)
* [`demo/thread.rb`](demo/thread.rb)
* [`demo/ractor.rb`](demo/ractor.rb)
* [`demo/process_pipe.rb`](demo/process_pipe.rb)
* [`demo/process_socket.rb`](demo/process_socket.rb)

See [config/example.cfg](config/example.cfg) for configuration.
It will be loaded by default.
Note that `serial.rb` and `fiber.rb` have no concurrency and cannot use
multiple miners or movers.

Execute via e.g. `ruby -Ilib demo/thread.rb`

### Concurrency Strategies

#### [Serial](demo/serial.rb)

One miner, one mover.  The miner mines to a depth, then loads the ore.
When the mover has a full batch, the batch is moved while the miner waits.

#### [Fibers](demo/fiber.rb)

Without a Fiber Scheduler, this just changes some organizational things.
Again, one miner, one mover.  The mover has its own fiber, and the mining
fiber can pass ore to the moving fiber.  There is no concurrency, so the
performance is roughly the same as before.

#### [Fiber Scheduler](demo/fiber_scheduler.rb)

TBD

#### [Threads](demo/thread.rb)

An array of mining threads and an array of moving threads.
A single shared queue for loading ore from miners to movers.
All threads contend for the same execution lock (GVL).

#### [Ractors](demo/ractor.rb)

Moving threads execute in their own ractor.
Mining threads contend against mining threads.  Moving threads, likewise.

#### [Processes with pipes](demo/process_pipe.rb)

Similar to ractors, but using `Process.fork` for movers, using a pipe to send
ore from the parent mining process.

#### [Processes with sockets](demo/process_socket.rb)

As above, but with Unix sockets (*not* network sockets), using any of
`SOCK_STREAM` `SOCK_DGRAM` `SOCK_SEQPACKET` socket types.
In all cases, ore amounts are 4 bytes so the types behave roughly equivalently.

# Multitasking

*Multitasking* here means "the most general sense of performing several tasks
or actions *at the same time*".  *At the same time* can mean fast switching
between tasks, or left and right hands operating truly in parallel.

## Concurrency

In the broadest sense, two tasks are *concurrent* if they happen *at the
same time*, as above.  When I tell Siri to call home while I drive, I perform
these tasks concurrently.

## Parallelism

In the strictest sense of parallelism, one executes several *identical* tasks
using multiple *facilities* that operate independently and in parallel.
Multiple lanes on a highway offer parallelism for the task of driving from
A to B.

If there is a bucket brigade to put out a fire, all members of the brigade are
operating in parallel.  The last brigade member is dousing the fire instead of
handing the bucket to the next member.  While this might not meet the most
strict definition of parallelism, it is broadly accepted as parallel.  It is
certainly concurrent.  Often though, *concurrent* means *merely concurrent*,
where there is only one *facility* switching between tasks rather than multiple
devices operating in parallel.

## Multitasking from the perspective of the OS (Linux, Windows, MacOS)

* A modern OS executes _threads_ within a _process_
* Processes are mostly about accounting and containment
  - Organization and safety from other processes and users
* By default, a process has a single thread of execution
* A single-threaded process cannot (easily) perform two tasks concurrently
  - Maybe it implements green threads or coroutines?
* A process can (easily) create additional threads for multitasking
  - Either within this process or via spawning a child process
* Process spawning implies more overhead than thread creation
  - Threads can only share memory within a process
  - fork() / CoW can provide thread-like efficiency
* Child processes are managed differently than threads
  - Memory protection
  - OS integration / init system

# Multitasking in Ruby

The default Ruby runtime is known as CRuby, named for its implementation in
the C language, also known as MRI (Matz Ruby Interpreter), named for its
creator Yukihiro Matsumoto.  Some history:

## Before YARV (up to Ruby 1.9):

* Execute-as-we-interpret
* Ruby code executes as the main thread of the main process
* Green threads implemented and scheduled by the runtime (not OS threads)
* GIL (Global Interpreter Lock) implies threads cannot execute in parallel
* Occasional concurrency, when a waiting thread is scheduled out in favor of a
  running thread
  - `schedule(waiting, running) YES`
  - `schedule(waiting, waiting) NO`
  - `schedule(running, running) NO`
  - `schedule(running, waiting) OH DEAR`

## YARV (Ruby 1.9 through 3.x):

* Interpret to bytecode, then execute
* YARV (Yet Another Ruby VM) is introduced, providing a runtime virtual
  machine for executing bytecode
* Fiber is introduced for cooperative multitasking, lighter than threads
* Ruby code executes as the main fiber of the main thread of the main process
* Ruby threads are implemented as OS threads, scheduled by the OS
* YARV is single threaded (not threadsafe) thus requring a Global VM Lock (GVL)
  - GVL is more fine grained than GIL
  - Threads explicitly give up the execution lock when waiting (IO, sleep, etc)
* YARV typically achieves 2-4x concurrency with multiple threads
  - Less concurrency when threads are CPU bound (thus waiting on GVL)
  - More concurrency when threads are IO bound (thus yielding GVL)
  - Less concurrency when not enough threads (GVL is underutilized)
  - More waiting (BAD!) when too many threads (GVL is under contention)
  - Thus, tuning is required, with many pathological cases
  - Thread pools (where most threads are idle) make tuning easier but still
    required
* As before, processes can be spawned for more more true parallelism
  - typically via `fork` with Copy-on-write for efficiency
  - management of child process lifecycles can be more difficult than
    multithreading
  - multiprocessing and multithreading can be combined, often with differing
    task shapes
* Fibers offer even lighter weight concurrency primitives

### Fibers

```
Fiber.yield(arg) # call within a Fiber to suspend execution and yield a value
Fiber#resume     # tell a Fiber to proceed and return the next yielded value
```

```ruby
fiber = Fiber.new do
  Fiber.yield 1
  2
end

fiber.resume
#=> 1

fiber.resume
#=> 2

fiber.resume
# FiberError: attempt to resume a terminated fiber
```

Any argument(s) passed to `Fiber#resume` on its first call (to start the Fiber)
will be passed to the `Fiber.new` block:

```ruby
fiber = Fiber.new do |arg1, arg2|
  Fiber.yield arg1
  arg2
end

fiber.resume(:x, :y)
#=> :x

fiber.resume
#=> :y
```

## YARV with `Fiber::Scheduler` (Ruby 3.x)

* Non-blocking fibers are introduced
  - any waits that would cause a fiber to block will cause the fiber to suspend
  - `Fiber::Scheduler` is introduced to manage non-blocking fibers

### Non-blocking Fibers

The concept of non-blocking fiber was introduced in Ruby 3.0. A non-blocking
fiber, when reaching a operation that would normally block the fiber (like
sleep, or wait for another process or I/O) will yield control to other fibers
and allow the scheduler to handle blocking and waking up (resuming) this fiber
when it can proceed.

For a Fiber to behave as non-blocking, it need to be created in `Fiber.new`
with `blocking: false` (which is the default), and `Fiber.scheduler` should be
set with `Fiber.set_scheduler`. If `Fiber.scheduler` is not set in the current
thread, blocking and non-blocking fibers’ behavior is identical.

Thus, any fiber without a scheduler is a blocking fiber.  If a fiber is created
with `blocking: true`, it is a blocking fiber.  Otherwise, if it has a
scheduler, it is non-blocking.

### Fiber scheduling

```
Fiber.scheduler     # get the current scheduler
Fiber.set_scheduler # set the current scheduler
Fiber.schedule      # perform a given block in a non-blocking manner
Fiber::Scheduler    # scheduler interface
```

### `Fiber::Scheduler`

* `Fiber::Scheduler` is **not an implementation** but an **interface**
* The implementation is provided by a library / gem / user

## YARV with Ractors (Ruby 3.x, experimental)

* YARV allows multiple threads but locks areas where multiple threads have
  access to the same data
* Ractors are introduced, with no shared data, requiring messages to be passed
  between Ractors
* Ruby code executes as the main Fiber of the main Thread of the main Ractor
  of the main Process
* The default thread within each Ractor has its own OS thread, with as much
  parallelism as the host OS provides
* Additional threads spawned by a Ractor are normal OS threads but they must
  contend for the Ractor Lock (RL) to execute on YARV

### Ractors

Ractors are an abstraction and a container for threads.  Threads within a
Ractor can share memory.  Threads must use message passaging to communicate
across Ractors.  Also, Ractors hold the execution lock on YARV, so threads
in different Ractors have zero contention.

```ruby
# get the current Ractor object
r = Ractor.current

# create a new Ractor (block will execute in parallel via thread creation)
Ractor.new(arg1, arg2, etc) { |arg1, arg2, etc|
  # now use arg1 and arg2 from outside
}
```

* Ractors communicate via messages
* send via outgoing port
* receive via incoming port (infinite storage, FIFO)

```
Ractor#send    - puts a message at the incoming port of a Ractor
Ractor.receive - returns a message from the current Ractor's incoming port
Ractor.yield   - current Ractor sends a message on the outgoing port
Ractor#take    - returns the next outgoing message from a Ractor
```

## Processes

There are many ways to create a process in Ruby, some more useful than
others.  My favorites:

* `Process.fork` - when called with a block, the block is only executed in the
  child subprocess
* `Process.spawn` - extensive options, nonblocking, call `Process.wait(pid)`
  to get the result
* `Open3.popen3` - for access to `STDIN` `STDOUT` `STDERR`

### IPC

* Pipes
  - `IO.pipe` (streaming / bytes / unidirectional)
* Unix sockets
  - `UNIXSocket.pair :RAW`
  - `UNIXSocket.pair :DGRAM`  (datagram / message / "like UDP")
  - `UNIXSocket.pair :STREAM` (streaming / bytes / "like TCP")
