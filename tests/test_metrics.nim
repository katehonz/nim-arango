import std/[unittest]
import ../src/nim_arango/metrics

suite "Metrics":
  test "counter increments":
    let c = newCounter("test_counter")
    check c.value == 0
    c.inc()
    check c.value == 1
    c.inc(5)
    check c.value == 6

  test "histogram observes":
    let h = newHistogram("test_hist", @[0.1, 0.5, 1.0, 5.0])
    h.observe(0.05)
    h.observe(0.3)
    h.observe(2.0)
    check h.sum > 2.0
    check h.counts[0] == 1
    check h.counts[1] == 2
    check h.counts[2] == 2
    check h.counts[3] == 6

  test "registry getOrCreate":
    let c1 = getOrCreateCounter("registry_counter2")
    let c2 = getOrCreateCounter("registry_counter2")
    check c1 == c2
    c1.inc()
    check c2.value == 1

  test "render metrics":
    discard getOrCreateCounter("render_test2")
    let output = renderMetrics()
    check output.len > "render_test2".len
