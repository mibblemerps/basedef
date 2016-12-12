# Base States

## SAFE (`0`)

* All base defences shut down.
* Triggering detectors has no effect.

## NORMAL (`1`)

* Triggering mob detectors results in base-wide alarm for 10 seconds, isolation of sector, and purge after countdown of 10 seconds.

## HIGH ALERT (`2`)

* Triggering mob detectors results in isolation of sector and immediate purge.

## EMERGENCY (`3`)

* All sectors are isolated.
* Triggering mob detector results in immediate purge of sector.

## PURGE (`4`)

* Last resort.
* All sectors are isolated.
* Immediate purge of entire base.
* Reverts to *High Alert* after 16 seconds.
* Alarms sound during purge.
