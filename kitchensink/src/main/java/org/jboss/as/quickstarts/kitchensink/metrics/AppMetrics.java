/*
 * Business metrics for the kitchensink application, exposed to Prometheus.
 *
 * These are registered on the Prometheus client's default registry and rendered
 * by MetricsServlet at /kitchensink/metrics. They are APPLICATION metrics (what
 * the business cares about) and are intentionally separate from WildFly's
 * infrastructure metrics on :9990 (wildfly_/base_/vendor_).
 *
 * Naming follows Prometheus conventions: base names WITHOUT the _total suffix —
 * the client appends _total to counters automatically on exposition. So
 * "kitchensink_registrations" is exported as "kitchensink_registrations_total".
 */
package org.jboss.as.quickstarts.kitchensink.metrics;

import io.prometheus.metrics.core.metrics.Counter;
import io.prometheus.metrics.core.metrics.Gauge;
import io.prometheus.metrics.core.metrics.Histogram;

public final class AppMetrics {

    /** Successful member registrations (RED "rate" for the business action). */
    public static final Counter REGISTRATIONS = Counter.builder()
            .name("kitchensink_registrations")
            .help("Total successful member registrations")
            .register();

    /** Failed registrations, split by reason (validation / duplicate_email / error). */
    public static final Counter FAILURES = Counter.builder()
            .name("kitchensink_registration_failures")
            .help("Total failed member registrations by reason")
            .labelNames("reason")
            .register();

    /** Time to persist a registration — RED "duration" (avg + p95/p99 from buckets). */
    public static final Histogram DURATION = Histogram.builder()
            .name("kitchensink_registration_duration_seconds")
            .help("Time spent persisting a member registration, in seconds")
            .register();

    /** Current number of members in the database (business KPI). */
    public static final Gauge MEMBERS = Gauge.builder()
            .name("kitchensink_members")
            .help("Current number of registered members")
            .register();

    private AppMetrics() {
        // utility holder — not instantiable
    }
}
