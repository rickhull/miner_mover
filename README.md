[![Test Status](https://github.com/rickhull/miner_mover/actions/workflows/test.yaml/badge.svg)](https://github.com/rickhull/miner_mover/actions/workflows/test.yaml)

# Miner Mover

This project provides a basic  concurrency problem useful for exploring
different multitasking paradigms available in Ruby.  Fundamentally, there is a
set of miners and a set of movers.  The miner takes some amount of time to
mine ore, which is given to a mover.  When the mover has enough ore for a full
batch, the delivery will take some amount of time before more ore can be
loaded.

## Mining

The miner is given some depth (e.g. 1 to 100) to mine down to, which will
take an increasing amount of time with depth.  More depth provides greater ore
results as well.  Ore is gathered at each depth; either a fixed amount or
random, based on depth.  The amount of time spent mining each level is
independent and may be randomized.

https://github.com/rickhull/miner_mover/blob/02c6606244ba87486af9d89bd788880f05f4424a/lib/miner_mover.rb#L20-L34

## Moving

The mover has a batch size, say 10.  As the mover accumulates ore over time,
once the batch size is reached, the mover delivers the ore to the destination.
Larger batches take longer.  The delivery time can be randomized.

https://github.com/rickhull/miner_mover/blob/0116b2d524c74b8b9bf53064c0632529768c0ec8/lib/miner_mover.rb#L51-L75

# Multitasking

*Multitasking* here means "the most general sense of performing several tasks
or actions *at the same time*".  *At the same time* can mean fast switching
between tasks, or left and right hands operating truly in parallel.

## Concurrency

In the broadest sense, two things are *concurrent* if they happen *at the
same time*, as above.  When I tell Siri to call home while I drive, I am
performing these tasks concurrently.

## Parallelism

In the strictest sense of parallelism, one executes several *identical* tasks
using multiple *devices* that operate independently and in parallel.
Multiple lanes on a highway offer parallelism for the task of driving from
A to B.

If there is a bucket brigade to put out a fire, all members of the brigade are
operating in parallel.  The last brigade member is dousing the fire instead of
handing the bucket to the next member.  While this might not meet the most
strict definition of parallelism, it is broadly accepted as parallel.  It is
certainly concurrent.  Often though, *concurrent* means *merely concurrent*,
where there is only one *device* switching between tasks rather than multiple
devices operating in parallel.

## Multitasking from the perspective of the OS (Linux, Windows, MacOS)

* A modern OS executes _threads_ within a _process_
* Process is mostly about accounting and containment
  - organization and safety from other processes and users
* By default, a process has a single thread of execution
* A single-threaded process cannot (easily) perform two tasks concurrently
  - maybe it implements green threads or coroutines?
* A process can (easily) create additional threads for multitasking
  - Either within this process or via spawning a child process
* Process spawning implies more overhead than thread creation
  - Threads can only share memory within a process
  - fork / CoW can provide thread-like efficiency
* Child processes are managed differently than threads
  - memory protection
  - OS integration / init system

## Multitasking in Ruby

The default Ruby runtime is known as CRuby, named for its implementation in
the C language, also known as MRI (Matz Ruby Interpreter), named for its
creator Yukihiro Matsumoto.  Some history:

### Before YARV (up to Ruby 1.9):

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

### YARV (Ruby 1.9 through 3.x):

* Interpret to bytecode, then execute
* YARV (Yet Another Ruby VM) is introduced, providing a runtime virtual
  machine for executing bytecode
* Fiber is introduced for cooperative multitasking, lighter than threads
* Ruby code executes as the main fiber of the main thread of the main process
* Ruby threads are implemented as OS threads, scheduled by the OS
* YARV is single threaded (not threadsafe) thus requring a Global VM Lock (GVL)
  - GVL is more fine grained than GIL
  - Threads explicitly give up the execution lock when waiting (IO, sleep, etc)
* YARV typically achieves 2-5x concurrency with multiple threads
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
  - *to be continued...*

### YARV with FiberScheduler (Ruby 3.x)

* *to be continued...*

### YARV with Ractors (Ruby 3.x, experimental)

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

```
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
