## Prometheus-compatible metrics for nim-arango.

import std/[tables, strformat, strutils]

type
  Counter* = ref object
    name*: string
    value*: int64
    labels*: Table[string, string]

  Gauge* = ref object
    name*: string
    value*: float64
    labels*: Table[string, string]

  Histogram* = ref object
    name*: string
    buckets*: seq[float]
    counts*: seq[int64]
    sum*: float64
    labels*: Table[string, string]

  MetricsRegistry* = ref object
    counters*: Table[string, Counter]
    gauges*: Table[string, Gauge]
    histograms*: Table[string, Histogram]

var defaultRegistry*: MetricsRegistry

proc initMetrics*() =
  defaultRegistry = MetricsRegistry(
    counters: initTable[string, Counter](),
    gauges: initTable[string, Gauge](),
    histograms: initTable[string, Histogram](),
  )

proc newCounter*(name: string, labels: Table[string, string] = initTable[string, string]()): Counter =
  Counter(name: name, value: 0, labels: labels)

proc inc*(c: Counter, amount: int64 = 1) =
  c.value += amount

proc newGauge*(name: string, labels: Table[string, string] = initTable[string, string]()): Gauge =
  Gauge(name: name, value: 0.0, labels: labels)

proc set*(g: Gauge, value: float64) =
  g.value = value

proc inc*(g: Gauge, amount: float64 = 1.0) =
  g.value += amount

proc dec*(g: Gauge, amount: float64 = 1.0) =
  g.value -= amount

proc newHistogram*(name: string, buckets: seq[float], labels: Table[string, string] = initTable[string, string]()): Histogram =
  var counts = newSeq[int64](buckets.len + 1)
  Histogram(name: name, buckets: buckets, counts: counts, sum: 0.0, labels: labels)

proc observe*(h: Histogram, value: float64) =
  h.sum += value
  for i, b in h.buckets:
    if value <= b:
      h.counts[i] += 1
  # +Inf bucket (last element) always counts every observation
  h.counts[^1] += 1

proc getOrCreateCounter*(name: string, labels: Table[string, string] = initTable[string, string]()): Counter =
  if defaultRegistry == nil:
    initMetrics()
  let key = name
  if key notin defaultRegistry.counters:
    defaultRegistry.counters[key] = newCounter(name, labels)
  result = defaultRegistry.counters[key]

proc getOrCreateGauge*(name: string, labels: Table[string, string] = initTable[string, string]()): Gauge =
  if defaultRegistry == nil:
    initMetrics()
  let key = name
  if key notin defaultRegistry.gauges:
    defaultRegistry.gauges[key] = newGauge(name, labels)
  result = defaultRegistry.gauges[key]

proc getOrCreateHistogram*(name: string, buckets: seq[float], labels: Table[string, string] = initTable[string, string]()): Histogram =
  if defaultRegistry == nil:
    initMetrics()
  let key = name
  if key notin defaultRegistry.histograms:
    defaultRegistry.histograms[key] = newHistogram(name, buckets, labels)
  result = defaultRegistry.histograms[key]

proc renderMetrics*(): string =
  if defaultRegistry == nil:
    return ""
  var lines: seq[string] = @[]
  for _, c in defaultRegistry.counters:
    lines.add &"# TYPE {c.name} counter"
    lines.add &"{c.name} {c.value}"
  for _, g in defaultRegistry.gauges:
    lines.add &"# TYPE {g.name} gauge"
    lines.add &"{g.name} {g.value}"
  for _, h in defaultRegistry.histograms:
    lines.add &"# TYPE {h.name} histogram"
    for i, b in h.buckets:
      lines.add &"{h.name}_bucket{{le=\"{b}\"}} {h.counts[i]}"
    lines.add &"{h.name}_bucket{{le=\"+Inf\"}} {h.counts[^1]}"
    lines.add &"{h.name}_sum {h.sum}"
    lines.add &"{h.name}_count {h.counts[^1]}"
  result = lines.join("\n")

initMetrics()
