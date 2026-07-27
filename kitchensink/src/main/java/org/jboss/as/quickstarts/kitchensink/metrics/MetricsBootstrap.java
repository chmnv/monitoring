/*
 * Seeds the kitchensink_members gauge from the database once the app starts, so
 * Prometheus sees the real member count immediately (not only after the first
 * registration increments the gauge).
 */
package org.jboss.as.quickstarts.kitchensink.metrics;

import jakarta.annotation.PostConstruct;
import jakarta.ejb.Singleton;
import jakarta.ejb.Startup;
import jakarta.inject.Inject;
import java.util.logging.Logger;

import org.jboss.as.quickstarts.kitchensink.data.MemberRepository;

@Singleton
@Startup
public class MetricsBootstrap {

    @Inject
    private Logger log;

    @Inject
    private MemberRepository repository;

    @PostConstruct
    void seedMemberGauge() {
        long count = repository.countAll();
        AppMetrics.MEMBERS.set(count);
        // Pre-create labeled failure series at 0 so "Failures by Reason" never shows
        // "No data" before the first real failure after a restart.
        AppMetrics.FAILURES.labelValues("validation").inc(0);
        AppMetrics.FAILURES.labelValues("duplicate_email").inc(0);
        AppMetrics.FAILURES.labelValues("error").inc(0);
        // Field / constraint series for dashboard 10 (Registration Quality).
        String[][] fieldSeeds = {
                { "name", "Pattern" }, { "name", "Size" }, { "name", "NotNull" },
                { "email", "Email" }, { "email", "NotEmpty" }, { "email", "NotNull" }, { "email", "Unique" },
                { "phoneNumber", "Size" }, { "phoneNumber", "Digits" }, { "phoneNumber", "NotNull" }
        };
        for (String[] pair : fieldSeeds) {
            AppMetrics.FIELD_FAILURES.labelValues(pair[0], pair[1]).inc(0);
        }
        // Search outcomes for dashboard 11.
        for (String outcome : new String[] { "hit", "zero", "empty", "refine", "error" }) {
            AppMetrics.SEARCH.labelValues(outcome).inc(0);
        }
        log.info("Seeded kitchensink_members gauge = " + count + " and failure/search series");
    }
}
