/*
 * Seeds gauges / labeled series so dashboards are never empty after restart.
 */
package org.jboss.as.quickstarts.kitchensink.metrics;

import jakarta.annotation.PostConstruct;
import jakarta.ejb.Singleton;
import jakarta.ejb.Startup;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.logging.Logger;

import org.jboss.as.quickstarts.kitchensink.data.MemberRepository;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;

@Singleton
@Startup
public class MetricsBootstrap {

    @Inject
    private Logger log;

    @Inject
    private MemberRepository repository;

    @Inject
    private EntityManager em;

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
        // Auth outcomes for dashboard 12.
        for (String outcome : new String[] {
                "success", "bad_credentials", "unknown_user", "not_activated", "error"
        }) {
            AppMetrics.AUTH_ATTEMPTS.labelValues(outcome).inc(0);
        }
        AppMetrics.AUTH_LOGOUTS.inc(0);
        AppMetrics.ACTIVE_SESSIONS.set(0);
        // Activation outcomes for dashboard 13.
        for (String outcome : new String[] {
                "success", "invalid_token", "expired", "already_activated", "error"
        }) {
            AppMetrics.ACTIVATION_ATTEMPTS.labelValues(outcome).inc(0);
        }
        AppMetrics.ACCOUNTS_ACTIVATED.inc(0);
        long pending = em.createQuery(
                        "select count(a) from AuthAccount a where a.status = :s", Long.class)
                .setParameter("s", AuthAccount.STATUS_PENDING)
                .getSingleResult();
        AppMetrics.ACCOUNTS_PENDING.set(pending);
        log.info("Seeded kitchensink_members=" + count + " pending=" + pending
                + " and failure/search/auth/activation series");
    }
}
