/// Source of the current time. Injected so timers and records are testable.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
