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

    /**
     * Every POST /rest/members attempt (success or failure). Used with REGISTRATIONS /
     * FAILURES for success-rate and "friction" views on dashboard 10.
     */
    public static final Counter ATTEMPTS = Counter.builder()
            .name("kitchensink_registration_attempts")
            .help("Total member registration attempts (success + failure)")
            .register();

    /**
     * Bean-validation / uniqueness failures by field and constraint type.
     * Complements FAILURES{reason=validation} with a per-field deep dive (dashboard 10).
     * Does not replace or rename the existing reason counter.
     */
    public static final Counter FIELD_FAILURES = Counter.builder()
            .name("kitchensink_registration_field_failures")
            .help("Registration validation failures by field and constraint")
            .labelNames("field", "constraint")
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

    /**
     * Per-operation DB/JPA timing (find, persist+flush, count, …). Complements WildFly
     * pool average_usage_time / get_time (connection hold time at the pool layer).
     * For persist, registration flushes so the sample includes the INSERT SQL, not only
     * persistence-context enqueue. Business success counters are recorded after TX commit.
     */
    public static final Histogram DB_OPERATION = Histogram.builder()
            .name("kitchensink_db_operation_duration_seconds")
            .help("Time spent in a kitchensink DB/JPA operation, in seconds")
            .labelNames("operation")
            .register();

    /**
     * Member name search outcomes for dashboard 11 (Search & Discovery).
     * Outcomes: hit (matches > 0), zero (no matches), empty (blank q), refine (short q, len<=2).
     */
    public static final Counter SEARCH = Counter.builder()
            .name("kitchensink_searches")
            .help("Member search requests by outcome")
            .labelNames("outcome")
            .register();

    /** End-to-end search latency (API + DB), seconds. */
    public static final Histogram SEARCH_DURATION = Histogram.builder()
            .name("kitchensink_search_duration_seconds")
            .help("Time spent handling a member search request, in seconds")
            .register();

    /** How many members a search returned (0 for zero/empty). */
    public static final Histogram SEARCH_RESULTS = Histogram.builder()
            .name("kitchensink_search_results")
            .help("Number of members returned by a search")
            .register();

    private AppMetrics() {
        // utility holder — not instantiable
    }
}
