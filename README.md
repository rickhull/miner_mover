[![CI Status](https://github.com/rickhull/miner_mover/actions/workflows/ci.yaml/badge.svg)](https://github.com/rickhull/miner_mover/actions/workflows/ci.yaml)

# Rationale

A basic  concurrency problem useful for exploring different multitasking
paradigms available in Ruby.  Fundamentally, there is a set of miners
and a set of movers.  The miner takes some amount of time to mine ore,
which is given to a mover.  When the mover has enough ore for a full batch,
the delivery will take some amount of time before more ore can be loaded.

## Mining

The miner is given some depth (e.g. 1 to 100) to mine down to, which will
take an increasing amount of time with depth.  More depth provides greater ore
results as well.  Ore is gathered at each depth; either a fixed amount or
random, based on depth.  The amount of time spent mining each level is
independent and may be randomized.

## Moving

The mover has a batch size, say 10.  As the mover accumulates ore over time,
once the batch size is reached, the mover delivers the ore to the destination.
Larger batches take longer.  The delivery time can be randomized.

# Multitasking in Ruby

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
