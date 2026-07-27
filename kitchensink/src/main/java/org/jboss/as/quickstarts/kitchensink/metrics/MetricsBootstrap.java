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
        // Recovery outcomes for dashboard 14.
        for (String outcome : new String[] { "success", "unknown_user", "not_activated", "error" }) {
            AppMetrics.RECOVERY_REQUESTS.labelValues(outcome).inc(0);
        }
        for (String outcome : new String[] { "success", "invalid_token", "expired", "error" }) {
            AppMetrics.RECOVERY_RESETS.labelValues(outcome).inc(0);
        }
        AppMetrics.RECOVERY_COMPLETED.inc(0);
        long recoveryOpen = em.createQuery(
                        "select count(a) from AuthAccount a where a.recoveryToken is not null", Long.class)
                .getSingleResult();
        AppMetrics.RECOVERY_PENDING.set(recoveryOpen);
        // Authz outcomes for dashboard 15.
        String[] authzOutcomes = { "allowed", "denied", "unauthenticated", "error" };
        String[] authzOps = { "stats", "export", "set_role" };
        for (String outcome : authzOutcomes) {
            for (String op : authzOps) {
                AppMetrics.AUTHZ_ATTEMPTS.labelValues(outcome, op).inc(0);
            }
        }
        long admins = em.createQuery(
                        "select count(a) from AuthAccount a where a.role = :r", Long.class)
                .setParameter("r", AuthAccount.ROLE_ADMIN)
                .getSingleResult();
        long membersRole = em.createQuery(
                        "select count(a) from AuthAccount a where a.role = :r", Long.class)
                .setParameter("r", AuthAccount.ROLE_MEMBER)
                .getSingleResult();
        AppMetrics.ACCOUNTS_BY_ROLE.labelValues(AuthAccount.ROLE_ADMIN).set(admins);
        AppMetrics.ACCOUNTS_BY_ROLE.labelValues(AuthAccount.ROLE_MEMBER).set(membersRole);
        log.info("Seeded kitchensink_members=" + count + " pending=" + pending
                + " recoveryOpen=" + recoveryOpen + " admins=" + admins
                + " and failure/search/auth/activation/recovery/authz series");
    }
}
